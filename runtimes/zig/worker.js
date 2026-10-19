/*
    Compiles and runs Zig programs for Manabase, entirely in the browser:
    the Zig compiler itself, built for WebAssembly (./build), runs under a
    WASI shim with the standard library in an in-memory filesystem, and the
    program it produces runs in a second WASI instance. Bundled by ./build
    into Resources/runtimes/zig/worker.js.

    It speaks the protocol every runtime does (docs/runtimes.md), plus
    progress messages while it downloads and compiles:

      page -> worker   { id, code }
      worker -> page   { id, type: "progress", message }
      worker -> page   { id, type: "started" }        compiled; the program starts
      worker -> page   { id, type: "done", status, stdout, stderr, truncated }
      worker -> page   { type: "failed", message }    the runtime could not be loaded

    stdout is everything the program printed, to standard output and to
    standard error, in order: std.debug.print, the usual way to print in
    Zig, writes to standard error, and so do panics. stderr is the
    compiler's own output, shown in full so the learner can work with it.
    "started" is only sent once compiling has worked, so the page's time
    limit applies to running the program, not to compiling it.
*/
import { WASI, WASIProcExit, File, OpenFile, ConsoleStdout, PreopenDirectory, Directory, wasi } from "@bjorn3/browser_wasi_shim";

// Bytes of program output kept, as in the Ruby worker.
const MAX_OUTPUT_BYTES = 100000;

// The WebAssembly features programs may use: the same as the compiler's own
// (CPU in ./build), which browsers have had since about 2021.
const CPU = "mvp+bulk_memory+sign_ext+nontrapping_fptoint+mutable_globals+multivalue";

const COMPILE_ARGS = [
    "zig", "build-exe", "main.zig",
    // compiler_rt is built natively by ./build: the WebAssembly build of
    // the compiler cannot build it itself.
    "libcompiler_rt.a", "-fno-compiler-rt",
    "-target", "wasm32-wasi", "-mcpu", CPU, "-O", "Debug",
    "--zig-lib-dir", "lib", "--cache-dir", "cache", "--global-cache-dir", "cache",
    "-femit-bin=main.wasm",
];

/*
    Standard output and error, as a pipe. Zig's writers first try
    positional writes, and fall back to plain ones when told the file is a
    pipe (ESPIPE). The shim's ConsoleStdout says "not supported" instead,
    which Zig reports as WriteFailed.
*/
class Pipe extends ConsoleStdout {
    fd_pwrite() { return { ret: wasi.ERRNO_SPIPE, nwritten: 0 }; }
    fd_seek() { return { ret: wasi.ERRNO_SPIPE, offset: 0n }; }
    fd_filestat_get() { return { ret: 0, filestat: new wasi.Filestat(this.ino, wasi.FILETYPE_UNKNOWN, 0n) }; }
}

function collector() {
    const chunks = [];
    let bytes = 0, truncated = false;
    return {
        pipe: new Pipe((data) => {
            if (bytes >= MAX_OUTPUT_BYTES) { truncated = true; return; }
            const room = MAX_OUTPUT_BYTES - bytes;
            if (data.length > room) truncated = true;
            chunks.push(data.slice(0, room));
            bytes += Math.min(data.length, room);
        }),
        text: () => new TextDecoder().decode(concat(chunks)),
        truncated: () => truncated,
    };
}

function concat(chunks) {
    const all = new Uint8Array(chunks.reduce((n, c) => n + c.length, 0));
    let at = 0;
    for (const c of chunks) { all.set(c, at); at += c.length; }
    return all;
}

// Reads a ustar archive (./build makes one) into the shim's directories.
function untar(bytes) {
    const root = new Map(), text = new TextDecoder();
    for (let at = 0; at + 512 <= bytes.length; ) {
        const header = bytes.subarray(at, at + 512);
        if (header[0] === 0) break;
        const field = (from, to) => text.decode(header.subarray(from, to)).replace(/\0.*$/s, "");
        const prefix = field(345, 500);
        const name = (prefix ? prefix + "/" : "") + field(0, 100);
        const size = parseInt(field(124, 136).trim() || "0", 8);
        const type = header[156];      // "0" or 0 a file, "5" a directory
        at += 512;

        const parts = name.split("/").filter(Boolean);
        const isDirectory = type === 53;
        let dir = root;
        for (const part of isDirectory ? parts : parts.slice(0, -1)) {
            if (!dir.has(part)) dir.set(part, new Directory(new Map()));
            dir = dir.get(part).contents;
        }
        if (!isDirectory && (type === 48 || type === 0))
            dir.set(parts[parts.length - 1], new File(bytes.slice(at, at + size), { readonly: true }));
        at += Math.ceil(size / 512) * 512;
    }
    return root;
}

/*
    Runs a WASI program to the end. Returns its exit code: 0 or what it
    passed to exit, or null if it crashed (a panic ends in a trap).
*/
function start(module, args, out, err, files) {
    const fds = [new OpenFile(new File([])), out, err, new PreopenDirectory(".", files)];
    const runner = new WASI(args, [], fds, { debug: false });
    const instance = new WebAssembly.Instance(module, { wasi_snapshot_preview1: runner.wasiImport });
    try {
        return runner.start(instance);
    } catch (error) {
        if (error instanceof WASIProcExit) return error.code;
        return null;
    }
}

let toolchain = null;   // { compiler, lib, compilerRt }, once loaded
// Kept between runs, so that the standard library is only compiled once.
const cache = new Directory(new Map());

async function loadToolchain(progress) {
    if (toolchain) return toolchain;
    progress("Downloading the Zig compiler (about 5 MB, only the first time)\u2026");
    const here = (name) => new URL(name, self.location.href);
    const [compiler, lib, compilerRt] = await Promise.all([
        WebAssembly.compileStreaming(fetch(here("zig.wasm"))),
        fetch(here("lib.tar.gz")).then((r) => new Response(r.body.pipeThrough(new DecompressionStream("gzip"))).arrayBuffer()),
        fetch(here("libcompiler_rt.a")).then((r) => r.arrayBuffer()),
    ]);
    toolchain = { compiler, lib: untar(new Uint8Array(lib)), compilerRt: new Uint8Array(compilerRt) };
    return toolchain;
}

async function run(id, code) {
    const progress = (message) => postMessage({ id, type: "progress", message });
    const { compiler, lib, compilerRt } = await loadToolchain(progress);

    progress("Compiling\u2026");
    const files = new Map([
        ["lib", new Directory(lib)],
        ["cache", cache],
        ["libcompiler_rt.a", new File(compilerRt, { readonly: true })],
        ["main.zig", new File(new TextEncoder().encode(code))],
    ]);
    const compilerOutput = collector();
    const compiled = start(compiler, COMPILE_ARGS, compilerOutput.pipe, compilerOutput.pipe, files);
    const binary = files.get("main.wasm");

    if (compiled !== 0 || !binary || !binary.data.length) {
        const message = compilerOutput.text() || "The compiler stopped without saying why.\n";
        return postMessage({ id, type: "done", status: 1, stdout: "", stderr: message, truncated: false });
    }

    progress("Running\u2026");
    postMessage({ id, type: "started" });
    const program = await WebAssembly.compile(binary.data);
    const output = collector();
    const exitCode = start(program, ["main"], output.pipe, output.pipe, new Map());

    let stderr = compilerOutput.text();
    if (exitCode === null) stderr += "The program crashed.\n";
    else if (exitCode !== 0) stderr += `The program exited with status ${exitCode}.\n`;

    postMessage({
        id, type: "done",
        status: exitCode === 0 ? 0 : 1,
        stdout: output.text(), stderr, truncated: output.truncated(),
    });
}

// One program at a time, in order: a run awaits while it loads and between
// compiling and running, and a second message must not slip in there.
let queue = Promise.resolve();
onmessage = (event) => {
    const { id, code } = event.data;
    queue = queue.then(() => run(id, code)).catch((error) => postMessage({ type: "failed", message: String(error) }));
};
