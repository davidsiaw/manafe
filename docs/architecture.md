# Architecture

The app is a Cappuccino single-page app: Objective-J classes, compiled in the browser in development (chino.md) and ahead of time for a release build. It holds no data of its own; everything comes from the backend's API.

## Files

```
main.j               Entry point. Calls CPApplicationMain.
AppController.j      Startup, routing, the stacked pages, and the account flows.
Config.j.erb         API_BASE_URL, rendered from the environment (below).
ApiClient.j          JSON over XMLHttpRequest, with the session as a bearer token.
AuthStore.j          The session and the learner's state, in localStorage. Pure logic.
Router.j             URL hash to screen, and back. Pure logic.
Passkeys.j           WebAuthn JSON <-> navigator.credentials. Pure logic apart from the last functions.
TopBar.j             Courses, My progress, and the account buttons.
PageView.j           A page of headings, text, buttons, inputs and course cards, stacked top to bottom.
CourseController.j   The course screen: revision switch, problem tree, problem.
CodeEditor.j         The editor for code problems, and CodeBlockView for code in problem text:
                     CodeMirror, loaded when first needed.
CodeRunner.j         Runs a learner's program in a Web Worker (runtimes.md).
CodeRun.j            Where a language's runtime is, and what to show for a run. Pure logic.
CourseTree.j         The problem tree, what is solved in the round shown, and row labels. Pure logic.
SidebarController.j  The CPOutlineView on the left of the course screen.
ProblemView.j        A problem, and its choices or its code editor, Run and Check answer.
RichTextView.j       Problem text: prose in labels, code in highlighted read-only blocks.
TextFormat.j         Splits problem text from YAML into prose and code, and reflows the prose. Pure logic.
Chinofile            App metadata: name (the page title), identifier, author.
Resources/           Static assets copied into the build; runtimes/ holds the language runtimes,
                     editors/ the bundled code editor.
runtimes/, editors/  How to build those (runtimes.md). Not part of the app.
tests/               Browser specs (tests/spec) and unit tests (tests/unit). See testing.md.
scripts/             The rspec, ojtest and build wrappers, on PATH in the image.
bin/rename           Renames the app (Chinofile name and identifier, smoke spec).
```

"Pure logic" files (`AuthStore`, `Router`, `Passkeys`, `CourseTree`, `TextFormat`, `CodeRun`) touch no AppKit and no browser API, and have unit tests in `tests/unit/`. Keep logic there where you can: it is far cheaper to test than a view.

## Screens

The window is the `TopBar` across the top and, below it, one screen, chosen by the URL hash (`Router.j`):

| Hash | Screen | Built by |
|---|---|---|
| `#/` (and anything unknown) | The course menu: a card per course, with progress | `AppController -showMenu:` with a `PageView` |
| `#/courses/<id>` | A course, at the first problem not yet solved | `CourseController` |
| `#/courses/<id>/<problem>` | A course, at that problem | `CourseController` |
| `#/revise/<id>[/<problem>]` | The same, in revision mode | `CourseController` |
| `#/me` | My progress: email or a prompt to register, and each course started | `AppController -showProfile:` |
| `#/register` | Email and "Create passkey" | `AppController -showRegister` |

A logged-out browser sees the "You are logged out" page on every screen except `#/register` (accounts.md).

Navigation always goes through the URL: buttons and the sidebar set `window.location.hash`, and the `hashchange` listener calls `-route`. This keeps back, reload and links working. Two consequences:

- Do not both set the hash and call `-route`: the screen is then built twice, and with it every request it makes. Where a change of who the learner is must also change screen, `-authChangedNavigatingTo:` does exactly one of the two.
- Use `window.location.replace(...)` to fill in a URL (such as the first unsolved problem for `#/courses/<id>`) so that back does not return to the incomplete one.

The course menu and My progress are rebuilt on every visit. `routeGeneration` discards answers to requests made for a screen the learner has already left. The course screen's `CourseController` is kept while the learner stays in the same course, and dropped when the course or the learner changes.

## Startup

`-applicationDidFinishLaunching:` builds the window, then `-start` works out who the learner is (accounts.md): it checks a stored session with `GET /me`, or creates an anonymous learner, or, for a logged-out browser, does nothing. Then `-authChanged` updates the top bar and routes. If the server rejects the session, the app starts over once; a second rejection in the same page load shows a message instead, because starting over again would create learners in a loop (this once created 54,000 of them).

## Talking to the backend

`ApiClient` sends JSON with `XMLHttpRequest`, adds `Authorization: Bearer <token>` when it has a token, and calls back with `(status, body)`; status 0 means the server could not be reached. After each callback it flushes Cappuccino's run loop, because AppKit only redraws inside its own run loop (cappuccino.md). Callers handle errors themselves, usually by showing a message with the status, and treat 401 as a lost session.

## Configuration

`Config.j.erb` is rendered by chino with ERB from the environment of the chino process, when it serves the file and in `chino build`:

| Constant | Environment variable | Default |
|---|---|---|
| `API_BASE_URL` | `API_BASE_URL` | `http://localhost:3000/api/v1` |

Heighliner.config sets it to `https://manabe.<suffix>/api/v1`, the backend's heighliner environment. A release build bakes in whatever the environment held at build time.

## The dev image

The `Dockerfile` serves both as the heighliner app image and as the CI test image.

- `build-essential` compiles the native extensions in puma and nio4r.
- `nodejs` and `npm` install `@objj/cappuccino`, which provides `jake` for `chino build` and `ojtest` for the unit tests.
- `/app/scripts` is on PATH. Because the wrappers are found in the source tree, a checkout bind-mounted over `/app` in CI runs its own copies.
- The app gems and the test gems are two separate bundles (`Gemfile`, `tests/Gemfile`).

## Origins

The repository started as [chino-base](https://github.com/davidsiaw/chino-base), a starting point for chino apps, and was renamed with `bin/rename Manabase`. The Chinofile's author and company are still the template's placeholders.
