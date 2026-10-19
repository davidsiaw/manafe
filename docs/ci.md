# CI

The workflows live in `.github/workflows/`. All of them run on pull requests, on the merge queue and on pushes to `master`, using GitHub-hosted `ubuntu-latest` runners.

| Workflow | What it runs |
|---|---|
| `ojtest.yml` | `scripts/ojtest` |
| `rspec.yml` | `scripts/rspec`, with a `selenium/standalone-chromium` service container |
| `build.yml` | `scripts/build`, as a compile check. |
| `static-site.yml` | `scripts/static-site`, uploading the static site as a GitHub Pages artifact (deployment.md). No deploy job yet. |

Each workflow does the same two things:

1. It builds the same `Dockerfile` that heighliner uses, with `docker/build-push-action`. The layer cache is `type=gha,scope=chino-dev`, and all three workflows share it.
2. It runs the wrapper with `docker run`, using the wrapper as the `--entrypoint`. The checkout is bind-mounted over `/app`, so the run uses this commit's scripts and tests rather than the copy baked into the image. The container runs as `-u $(id -u)`, so files written to the workspace belong to the runner. `HOME` is set to `/tmp` because that user has no home directory in the image.

## rspec specifics

- The app container joins the job's network (`${{ job.container.network }}`) with `--network-alias chino-app`, and chrome reaches it by that alias. Setting only `--hostname` would not work, because other containers cannot resolve it.
- `CHROME_HOSTNAME=chrome` matches the name of the service container.
- Any environment variable that the SPA or the specs need must be passed to `docker run` with `-e`. A job-level `env:` entry does not reach the container. If you forget, the SPA still builds with empty constants, and the resulting failures look like app bugs.
- Selenium needs `--shm-size=2g`; without it Chromium crashes on large pages.

## The Zig runtime

`Resources/runtimes/zig/` is not committed (runtimes.md), so `rspec.yml`, `build.yml` and `static-site.yml` build it before their main step, by running `runtimes/zig/build` in the dev image with `WORK_DIR=/app/.zig-build`. `actions/cache` keeps `.zig-build/` (the Zig downloads and Zig's build cache) between runs, keyed on `runtimes/zig/**`; a run that finds it builds in seconds, a run without it takes about 3 minutes. `ojtest.yml` does not need it.

Any change to the Dockerfile invalidates the cache for all three workflows. The first run after such a change does a full build: apt, npm and two bundle installs.
