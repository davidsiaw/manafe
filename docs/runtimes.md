# Runtimes: running learners' code in the browser

Code problems (`type: code`) are programs the learner writes in the course screen. The app runs them in the browser and sends the backend what they printed; the backend compares it with the problem's expected output, which it never sends (backend [courses/README.md](../../backend/courses/README.md)). Nothing runs on a server.

## Layout

```
Resources/runtimes/<language>/   what the browser loads; copied into the build
  worker.js                      the Web Worker: speaks the protocol below
  ...                            whatever it needs (ruby: mruby.js and mruby.wasm;
                                 zig: zig.wasm, lib.tar.gz, libcompiler_rt.a)
runtimes/<runtime>/              how to build those files; not part of the app
                                 (runtimes/mruby/, runtimes/zig/)
CodeRun.j                        pure logic: where a language's worker is, what to show for a run
CodeRunner.j                     starts workers, times programs out
CodeEditor.j                     the editor; see below
Resources/editors/codemirror/    CodeMirror 6, bundled; copied into the build
editors/codemirror/              how to bundle it
```

A runtime is downloaded only when the learner first runs a program in its language, and then kept for the page load (one `CodeRunner`, shared by every `ProblemView`). The app has no list of languages: a problem's `language` names the directory, which must be a plain slug (`CodeRunWorkerResource`). The backend's `Problem::LANGUAGES` is the list of what courses may use; add a language there when its runtime is here.

## The protocol

Every `worker.js` speaks the same messages, so `CodeRunner` knows nothing about any language:

| Direction | Message | Meaning |
|---|---|---|
| page to worker | `{id, code}` | Run this program. |
| worker to page | `{id, type: "progress", message}` | Optional: what it is doing meanwhile ("Downloading the Zig compiler…", "Compiling…"). `CodeRunner` passes it to the run's progress function, and `ProblemView` shows it in the output box. |
| worker to page | `{id, type: "started"}` | The runtime is loaded (and, for a compiled language, the program compiled) and the program is starting. The timeout starts here, so downloading and compiling do not count against the program. |
| worker to page | `{id, type: "done", status, stdout, stderr, truncated}` | Finished. `stdout` is what the program printed: what Check answer sends. `status` 0 means it ran to the end; anything else means it failed (or did not compile) and `stderr` says why. `truncated` means output beyond the worker's limit was dropped. |
| worker to page | `{type: "failed", message}` | The runtime could not be loaded. |

A worker runs one program at a time, and starts each in a fresh interpreter or instance, so programs cannot see each other's variables.

## Why a worker

A program that never ends (`loop { }`) would freeze the page if it ran on the main thread, and JavaScript cannot interrupt a running WebAssembly call. In a worker, `CodeRunner` terminates the worker after `CODE_RUN_TIMEOUT_SECONDS` (5) and starts a new one for the next run. Starting a run while another is running, or showing another problem, terminates the old one too.

Output is capped twice: the Ruby worker keeps at most 100,000 bytes, and `CodeRunOutputText` shows at most 20,000 characters (a deep recursion's backtrace is 500 lines).

## Ruby: mruby

`Resources/runtimes/ruby/` is [mruby](https://mruby.org) 3.4.0 compiled to WebAssembly with Emscripten: about 600 KB of `.wasm`, about 230 KB gzipped. `mruby.js` and `mruby.wasm` are committed, with mruby's `LICENSE`, so neither the app's build nor its tests need Emscripten.

To rebuild them (for another mruby version or other gems):

```sh
runtimes/mruby/build
```

It needs git, a C compiler, bison and Ruby with rake, and installs the pinned Emscripten (`EMSDK_VERSION`) into its work directory, `~/.cache/manabase-mruby` (override with `WORK_DIR`), unless `emcc` is already on PATH. The work directory is outside the repository on purpose: chino compiles every `.j` file in the tree, and the Docker image copies all of it. A build takes about a minute after the first download.

- `build_config.rb` picks mruby's gems: the standard library, its extensions, Math/Rational/Complex/bigint, metaprogramming, the compiler (to run source rather than bytecode) and `mruby-io`, which is where `puts`, `print` and `p` live in mruby 3.4.
- `runner.c` is the entry point, `manabase_run(code)`: a fresh `mrb_state`, run, print any exception and its backtrace to stderr, close.
- mruby compiles with `-g`; the link step drops it, or the `.wasm` comes out five times larger.
- `worker.js` gives Emscripten byte callbacks for stdout and stderr, rather than its default line-buffered `print`. With the default, output that does not end in a new line (`print "x"`) is lost, and it is decoded per line, not as UTF-8. stdin is always at its end, so `gets` returns nil.

### mruby is not CRuby

Most of what a beginner writes behaves the same, and the sample course's answers print the same in both (checked when it was written). Known differences that a course author can trip over:

- No `it` block parameter (CRuby 3.4); `_1` works.
- `10.0 / 3` prints `3.33333333333333`, CRuby `3.3333333333333335`: mruby prints Floats with fewer digits. Avoid printing inexact Floats in expected output.
- No `require`, no files or network, no `gets` input, no threads.
- Error messages and backtraces are worded differently.

Expected output must be what **mruby** prints. Run the reference solution through the runtime before committing a problem; with Node, `require('./Resources/runtimes/ruby/mruby.js')` works, since the build targets Node as well as workers.

## Zig: the real compiler, in WebAssembly

`Resources/runtimes/zig/` runs Zig 0.17.0 entirely in the browser. Unlike the other runtimes it is **not committed** (8.5 MB): run `runtimes/zig/build` after cloning; `scripts/rspec` and `scripts/build` refuse to run without it. In it, the Zig compiler itself, built for `wasm32-wasi`, compiles the learner's program into WebAssembly, which then runs. Zig is written in Zig and can target WebAssembly itself, so no Emscripten is involved. The recipe is the one the [zigtools playground](https://github.com/zigtools/playground) uses.

| File | Size | What |
|---|---|---|
| `zig.wasm` | 4.2 MB (1.3 MB gzipped) | the compiler, built with `-Ddev=wasm`: only the WebAssembly backend, no LLVM |
| `lib.tar.gz` | 3.4 MB | `lib/std` and `lib/ubsan_rt.zig`, which the compiler reads as source |
| `libcompiler_rt.a` | 0.2 MB | compiler_rt, built natively: the WebAssembly compiler cannot build it itself |
| `worker.js` | 30 KB | `runtimes/zig/worker.js` bundled with `@bjorn3/browser_wasi_shim` |

The first run downloads about 5 MB. In the worker, the compiler runs under the WASI shim with the library in an in-memory filesystem (untarred with the browser's `DecompressionStream`), writes `main.wasm`, and a second WASI instance runs that. Measured in Chromium: the first compile of a session about 1.4 s, later ones about 0.3 to 0.9 s, as the compiled standard library stays in the worker's cache directory; it uses about 230 MB of memory while compiling.

What the worker reports:

- `stdout` is everything the program printed to standard output and standard error, in order. `std.debug.print`, Zig's usual way to print, writes to standard error, and courses use it a lot. A panic's message lands there too, with `status` 1 and "The program crashed." in `stderr`.
- `stderr` is the compiler's output, in full, with nothing trimmed: like HDLBits, the learner gets everything the compiler said. A program that does not compile has `status` 1 and no `stdout`.
- "started" is sent after compiling, so the time limit is for running the program only.

`runtimes/zig/build` does nothing when the outputs are already built from the same inputs (it compares the build script, the worker and the npm files with `.stamp` in the output directory); `--force` rebuilds anyway. From nothing it takes about 3 minutes: 76 MB of downloads, then about 2 minutes compiling the compiler. It downloads the pinned Zig release for the machine it runs on (checksum from ziglang.org's release index) and the source (pinned checksum), builds the compiler, compiler_rt and the tarball, and bundles the worker, using `~/.cache/manabase-zig` (`WORK_DIR` to override; CI uses `.zig-build/` in the checkout, which is ignored), with Zig's own build cache inside it. The dev image has `xz-utils` for Zig's `.tar.xz` files, so it can also run in the container: `heighliner login runtimes/zig/build`, which writes into the mounted source. Things that were found the hard way, all handled there or in the worker:

- **Browser support.** Zig's default WebAssembly target uses reference types, which Chrome only has since version 96, and the shared Selenium Chrome is 94 ("expected table index 0, found 0"). The compiler, compiler_rt and every program are built for an explicit feature set (`CPU` in `build` and in `worker.js`), which browsers have had since about 2021. Keep the two the same.
- **compiler_rt** must be prebuilt and passed as `libcompiler_rt.a` with `-fno-compiler-rt`; built by the WebAssembly compiler, its archive is rejected ("BadArchiveMagic").
- **Paths** must be relative to the "." preopen; absolute ones are refused.
- **stdout.** Zig's file writer first tries positional writes, and only falls back to plain ones on `ESPIPE`. The shim's `ConsoleStdout` answers "not supported", which Zig reports as `WriteFailed`; the worker's `Pipe` answers `ESPIPE`.
- **The shim logs every call** unless it is given `{ debug: false }`.
- **No `zig version`** and other subcommands in the cut-down compiler; only `build-exe` is used.
- **The tarball is ustar**, the format the worker's small tar reader handles. Every path in `lib/std` is short enough for it.

Zig is pre-1.0 and its standard library changes a lot between releases (0.17's stdout goes through `std.Io`). A course is written for one version; upgrading the runtime means checking every problem again (backend courses/README.md, "Checking code problems").

## The editor: CodeMirror

The editor is [CodeMirror 6](https://codemirror.net), bundled with esbuild into one script, `Resources/editors/codemirror/codemirror.js` (about 300 KB, 100 KB gzipped), with the bundled packages' licences in `LICENSES.txt` beside it. Like a runtime, it is committed, and loaded only when the first code problem is shown.

- `editors/codemirror/editor.js` is the entry point. It picks the extensions (highlighting per language, line numbers, brackets, history, indentation) and exposes a small API, `window.ManabaseCodeEditor.create(parent, {code, language})` returning `getCode`, `setCode`, `focus` and `destroy`, so `CodeEditor.j` knows nothing else about CodeMirror.
- `editors/codemirror/build` installs the versions pinned in `package.json` and `package-lock.json` into `~/.cache/manabase-codemirror` (outside the repository, like the mruby build) and bundles. To update CodeMirror, change the versions, delete the lock file, run it, and commit all of them.
- Highlighting for a language is a line in `LANGUAGES` in `editor.js`; Ruby and Rust use the legacy stream modes from `@codemirror/legacy-modes`. Zig has no maintained CodeMirror package, so `editors/codemirror/zig-mode.js` is a small stream mode of our own: keywords, types, builtins, strings, numbers and comments. Shell (for the git course) does too. A language without one gets a plain editor, `plain: true` (the paste box of a local problem) turns off line numbers and the rest, and `readOnly: true` (code in problem text) shows code highlighted, not editable, as tall as its content, in the same font and line height as `CodeBlockView`'s placeholder.
- If the script cannot be loaded, `CodeEditor` puts a plain textarea there instead, so the learner can still work.
- AppKit swallows keys meant for a DOM widget unless they are stopped on the way up (cappuccino.md).

## Languages with no runtime

A code problem can say `run: local`: the learner runs the program on their own computer and pastes the output (course-screen.md). That is how Rust is taught. Zig shows that a compiler can run in the browser well; a Rust compiler does too ([rubrc](https://github.com/oligamiq/rubrc), WASI builds of rustc and LLVM), but it downloads tens of megabytes, takes many seconds to start, needs cross-origin isolation headers on the whole app, and calls itself pre-release. Cut-down compilers that Emscripten could build, such as mrustc, skip the borrow checker, which is most of what a Rust beginner has to learn. Revisit when rubrc is stable, or compile on a server.

## Adding a language

1. Build its runtime into `Resources/runtimes/<language>/`, with a `worker.js` that speaks the protocol above. Put the build script and its sources in `runtimes/<runtime>/`, and commit the built files.
2. Add the language to `Problem::LANGUAGES` in the backend.
3. Add its highlighting to `LANGUAGES` in `editors/codemirror/editor.js` and rebuild the editor, if CodeMirror has a mode for it.
4. Add a spec like `tests/spec/code_spec.rb` that runs a real program, so a broken runtime fails the build.

A large runtime costs only the learners who open a problem in its language.
