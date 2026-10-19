# Roadmap and known gaps

The backend's [roadmap.md](../../backend/docs/roadmap.md) lists what is missing on the server. On this side:

- **More from code problems.** Ruby problems run in the browser, and Rust problems on the learner's computer (runtimes.md). Not there yet: Rust in the browser (runtimes.md says why), keeping what the learner typed across problems and reloads, more languages, and problems checked by tests rather than by exact output.
- **Richer problem text.** Code blocks are highlighted (course-screen.md), but the rest is plain: backticks are shown as they are, and there is no bold, no links and no images. Markdown would need a renderer, and images a place in the course format.
- **Account recovery and more passkeys per account**, once the backend has them.
- **Deployment**: the static site is built and uploaded as a Pages artifact on every push (deployment.md), but nothing publishes it yet. Turning on GitHub Pages is a deploy job and some settings, listed there. A site bakes in `API_BASE_URL`, so one backend per build.
- **The Chinofile** still has the template's author (`YourName`) and company (`YourCompany`), and the identifier `com.yourcompany.manabase`.
- **Accessibility and small screens** have not been looked at. The layout assumes a desktop-sized window.
