# Manabase: the system

This file is the same in `backend/docs/` and `frontend/docs/`. If you change it, change both.

## What it is

Manabase is a base system for interactive learning modules, modelled on [HDLBits](https://hdlbits.01xz.net/wiki/Andgate): a course is a tree of problems, shown as a collapsible sidebar, and each problem is a short explanation followed by an exercise. Answer it correctly and the problem is ticked. An exercise is either a multiple choice question or a program to write. Ruby programs run in the learner's browser; Rust programs run on the learner's own computer, and the learner pastes back what they printed.

What a student can do today:

- Pick a course from the course menu and work through its problems in any order.
- Write and run Ruby programs in the browser, and check them.
- Set up Rust on their own computer, run the course's Rust programs there, and paste back the output to check it.
- Use it anonymously, straight away. Progress is saved on the server against an anonymous learner.
- Register an email and a passkey to keep that progress, and log in and out with the passkey, on any device.
- Go through a course again in **revision mode**, from nothing, as often as they like, without losing their first time through. In a revision the choices are shuffled.
- See their progress per course on a personal page: problems solved, times completed, the current revision.

## Two repositories

They live side by side, normally as `manabase/backend` and `manabase/frontend`. They are separate git repositories; links between their docs assume that layout.

| | backend | frontend |
|---|---|---|
| What | JSON API, courses, accounts, progress | The single-page app students use |
| Stack | Rails 8, Grape, PostgreSQL, Redis/Sidekiq, Falcon | Cappuccino (Objective-J), served and built by the `chino` gem |
| Started from | the rails-zen template (`davidsiaw/rails-zen`) | the chino-base template (`davidsiaw/chino-base`) |
| Dev environment | heighliner `manabe` | heighliner `manafe` |
| Dev URL | `https://manabe.<suffix>/api/v1` | `https://manafe.<suffix>/` |

`<suffix>` is whatever `heighliner show http-suffix` prints (on the original machine, `localdev.astrobunny.net`). Plain `http://` redirects to `https://`.

The frontend holds no data and no rules: courses, correct answers, accounts and progress all live in the backend. Correct answers never leave the backend; it checks answers itself. For a code problem the frontend runs the learner's program and sends what it printed, and the backend compares that with the expected output.

## How they talk

- JSON over HTTPS, under `/api/v1`. The frontend's base URL comes from `API_BASE_URL` (frontend `Config.j.erb`).
- Every learner, anonymous or registered, has a session token. The frontend keeps it in `localStorage` and sends `Authorization: Bearer <token>`. The backend stores only a SHA-256 digest of it.
- CORS: the backend allows `FRONTEND_HOST`, or any origin when unset (the dev default).
- Passkeys belong to the frontend's site, because that is the page the browser runs them on. The backend is told that site with `WEBAUTHN_ORIGINS` and `WEBAUTHN_RP_ID`.

## Words

| Word | Meaning |
|---|---|
| Course | A directory of YAML in `backend/courses/`: a title, a tree of sections, and problems. |
| Section | A node of the sidebar tree. It may hold problems, subsections, or both. |
| Problem | One exercise: a title, explanatory text, a question, and either choices or a program to write. Identified by a slug unique in its course. |
| Learner | A student. Anonymous until registered with an email and a passkey. |
| Session | A bearer token identifying a learner. A browser has at most one. |
| Round | One time through a course. Round 1 is the first time; every revision is a further round. |
| Revision | A round after the first. The highest-numbered one is the *current* revision. |
| Completion | "This learner solved this problem in this round." |
| Completed (course) | A round in which every problem in the course is solved. Counted, not stored. |

## Decisions, and why

These were made deliberately; change them knowingly.

- **Courses are YAML on disk** in the backend repository, one file per problem, read on every request. Editing a course needs no deploy step and no restart, and diffs stay small. They are validated when loaded, and the backend's specs load every course, so a broken course fails the build.
- **Answers are checked by the backend**, so the frontend never has the correct choice.
- **Code runs in the browser, or on the learner's computer; the backend checks its output.** A language runtime (mruby, compiled to WebAssembly) runs the program in a Web Worker, and is downloaded only when a problem in that language is first run, so further languages cost nothing to learners who do not use them. No server has to run untrusted code. A language with no browser runtime (Rust: a compiler in the browser is tens of megabytes and not yet reliable) is run on the learner's computer instead (`run: local`). The price, either way, is that the backend trusts the output it is sent: a learner can mark a problem solved by posting the right output without a program. That is acceptable for practice, and wrong for anything graded.
- **Anonymous first.** A visitor can start at once. Registering keeps the same learner, so nothing is lost.
- **Passkeys, no passwords, usernameless login.** Registration asks for an email and creates a discoverable passkey; logging in just asks the browser for any passkey for the site. There is no email confirmation and no account recovery yet.
- **Logging in drops anonymous progress** in that browser; it is not merged into the account.
- **A browser that has logged in stays "logged out" after logout**, even across reloads: it asks to log in again (or create a new account) instead of quietly becoming anonymous, which would be confusing.
- **Progress is per round**, and round 1 needs no record of its own, so progress from before revisions existed is simply round 1. Whether a round is complete is computed against the course as it is now, so adding problems to a course makes earlier completions incomplete.
- **Revisions shuffle the choices**, in an order fixed per revision and problem, so that a learner has to know the answer rather than remember its position.
- **The frontend's browser specs mock the backend**, and the backend's specs cover the backend. Nothing tests the two together automatically; see each repo's testing notes for the manual end-to-end check.

## Where to read next

- Backend: [backend/docs/README.md](../../backend/docs/README.md)
- Frontend: [frontend/docs/README.md](../../frontend/docs/README.md)
- Things not built yet: each repo's `docs/roadmap.md`.
