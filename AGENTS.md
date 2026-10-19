# Manabase frontend: notes for agents

Read [docs/README.md](docs/README.md) before changing anything, and [docs/system.md](docs/system.md) if you are new here. The backend is in `../backend`, with its own `docs/`; [its api.md](../backend/docs/api.md) describes every endpoint this app calls.

The things most likely to bite:

- Start the container with `heighliner up -av`, which mounts the source, so a refresh shows an edit. Plain `heighliner up` serves a copy from the last build (docs/heighliner.md).
- Navigate by setting the URL hash and let the router build the screen; never both set the hash and route (docs/architecture.md).
- After an asynchronous callback, flush the run loop, or AppKit does not redraw (docs/cappuccino.md).
- Never retry a rejected session more than once: an unbounded retry once created 54,000 learners.
- Browser specs mock the backend. Queue every response the app will ask for, before the action that asks (docs/testing.md).
- Keep logic in the pure-logic files and unit test it there.
- `scripts/rspec`, `scripts/ojtest` and `scripts/build` must all pass.
