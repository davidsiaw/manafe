# Roadmap and known gaps

The backend's [roadmap.md](../../backend/docs/roadmap.md) lists what is missing on the server. On this side:

- **Code exercises.** `ProblemView` only knows multiple choice; a new problem type needs a view of its own (an editor, test output).
- **Rich problem text.** Text is plain, with backticks shown as they are. Markdown, code blocks in a monospace font and images would need a renderer and a place in the course format for images.
- **Account recovery and more passkeys per account**, once the backend has them.
- **Deployment**: nothing builds and publishes `build/` yet (for example to S3 from CI with OIDC credentials). A release build bakes in `API_BASE_URL` from the build environment.
- **The Chinofile** still has the template's author (`YourName`) and company (`YourCompany`), and the identifier `com.yourcompany.manabase`.
- **Accessibility and small screens** have not been looked at. The layout assumes a desktop-sized window.
