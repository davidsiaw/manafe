# Frontend docs

Notes for whoever works on this repository next, human or agent. Read [system.md](system.md) first: it explains what Manabase is, how this app and the backend fit together, and the decisions behind them. Then read the file for your task.

| File | Read it when |
|---|---|
| [system.md](system.md) | You are new here. The whole system, its words, and its decisions. Shared with the backend. |
| [architecture.md](architecture.md) | You are changing code. Files, screens and routing, startup, configuration, the dev image. |
| [accounts.md](accounts.md) | You are working on sessions, registration, login, logout or passkeys. |
| [course-screen.md](course-screen.md) | You are working on the course screen: the problem tree, problems, answering, revision mode. |
| [runtimes.md](runtimes.md) | You are working on code problems: running programs in the browser, the mruby runtime, adding a language. |
| [cappuccino.md](cappuccino.md) | You are writing views. AppKit behaviour that has surprised us. |
| [chino.md](chino.md) | You are touching the dev server, `chino build` or `.j.erb` files. |
| [testing.md](testing.md) | You are writing or running specs and unit tests. |
| [heighliner.md](heighliner.md) | You are running the app locally or from the pi sandbox. |
| [ci.md](ci.md) | You are changing `.github/workflows/`. |
| [deployment.md](deployment.md) | You are building the static site, hosting it, or setting up GitHub Pages. |
| [roadmap.md](roadmap.md) | You want to know what is not built yet. |

The backend has its own `docs/`, in `../backend/docs/`; its [api.md](../../backend/docs/api.md) describes every endpoint this app calls.

Every gotcha recorded here was hit for real at least once. If you hit a new one, add it.
