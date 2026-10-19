# Manabase frontend

The app students use in Manabase, a vibe-coded base system for interactive learning modules: a course menu, courses shown as a collapsible problem tree with a problem beside it, multiple choice exercises, code exercises (Ruby runs in the browser on mruby compiled to WebAssembly, Zig is compiled in the browser by the real Zig compiler built for WebAssembly, and Rust is run on the learner's computer and the output pasted back) in a CodeMirror editor, highlighted code in problem text, passkey accounts, a personal progress page, and revision mode for going through a course again. Everything it shows comes from the backend repository, normally checked out next to this one.

A [Cappuccino](https://www.cappuccino.dev) (Objective-J) single-page app, served and built by [chino](https://github.com/davidsiaw/chino), and started from the chino-base template.

## Running it

Start the backend first (`../backend`), then:

```sh
heighliner init manafe     # once
heighliner up -av          # -a mounts the source, so a browser refresh shows an edit
heighliner login runtimes/zig/build   # once: the Zig runtime is built, not committed
open "https://manafe.$(heighliner show http-suffix)"
```

## Testing

```sh
heighliner up -av          # -a mounts the source: edits show on refresh
heighliner login rspec     # browser specs, against a mock backend
heighliner login ojtest    # unit tests
heighliner login build     # the release build
```

## Static site

```sh
API_BASE_URL=https://api.example.com/api/v1 scripts/static-site   # writes site/
```

CI builds it on every push and uploads it as a GitHub Pages artifact: [docs/deployment.md](docs/deployment.md).

## Documentation

How the app is built, how it talks to the backend, accounts and passkeys, the course screen and revision mode, Cappuccino pitfalls, and testing: [docs/](docs/README.md). Start with [docs/system.md](docs/system.md).
