# Roadmap and known gaps

The backend's [roadmap.md](../../backend/docs/roadmap.md) lists what is missing on the server. On this side:

- **More from code problems.** Ruby problems run in the browser, and Rust problems on the learner's computer (runtimes.md). Not there yet: Rust in the browser (runtimes.md says why), keeping what the learner typed across problems and reloads, more languages, and problems checked by tests rather than by exact output.
- **Richer problem text.** Code blocks are highlighted (course-screen.md), but the rest is plain: backticks are shown as they are, and there is no bold, no links and no images. Markdown would need a renderer, and images a place in the course format.
- **Account recovery and more passkeys per account**, once the backend has them.
- **Deployment**: nothing builds and publishes `build/` yet (for example to S3 from CI with OIDC credentials). A release build bakes in `API_BASE_URL` from the build environment.
- **The Chinofile** still has the template's author (`YourName`) and company (`YourCompany`), and the identifier `com.yourcompany.manabase`.
- **Accessibility and small screens** have not been looked at. The layout assumes a desktop-sized window.
