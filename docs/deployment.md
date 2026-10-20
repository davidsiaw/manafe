# Deployment: the static site

The app is a static site: files, no server-side code. `scripts/static-site` builds it into `site/`, and the `static-site` workflow builds it on GitHub and deploys it to GitHub Pages at https://manafe.astrobunny.net.

## Building it

```sh
runtimes/zig/build                                        # once, if not built yet
API_BASE_URL=https://api.example.com/api/v1 scripts/static-site
```

- It runs `scripts/build` (the release build, `build/`) and copies it to `site/`, leaving out what a browser never loads: the frameworks' debug builds (45 MB), the CommonJS builds the compiler uses, AppKit's old Aristo theme, and Objective-J sources. That brings 80 MB down to about 21 MB, of which the Zig runtime is 8 MB. What to leave out was measured from a static server's request log, going through the course menu, every runtime and My progress; if a screen ever fails on the static site but not under chino, look for a 404 there first.
- `API_BASE_URL` is baked in (`Config.j.erb`), so a site is built for one backend. Unset or empty means `http://localhost:3000/api/v1`, with a warning.
- `site/` is ignored by git and by Docker. It is removed before every build: chino would otherwise compile the `.j` files of an old copy (it compiles every `.j` file in the tree, chino.md).

## Hosting it

Any static host works:

- **Every path is relative** and routing is in the URL's `#`, so the site works from a subdirectory, such as a GitHub Pages project site at `https://<owner>.github.io/<repo>/`, and needs no rewrite rules. Tested from a subdirectory with Python's `http.server`: courses, Ruby, Zig and multiple choice answers, Next, My progress.
- **`.wasm` must be served as `application/wasm`**: the Zig worker compiles the compiler with `WebAssembly.compileStreaming`, which refuses anything else. GitHub Pages, S3 and the common servers do.
- The first Zig problem downloads about 5 MB (runtimes.md); compression on the host helps the `.wasm` files (4.2 MB to 1.3 MB for the compiler).

The backend must be told about the site's address (backend development.md):

- `FRONTEND_HOSTS`: the sites' origins, comma separated, for CORS, for example `https://manafe.astrobunny.net,https://manamo.astrobunny.net`.
- `WEBAUTHN_ORIGINS` and `WEBAUTHN_RP_ID`: passkeys belong to the site's domain (system.md). For a GitHub Pages project site the domain is `<owner>.github.io`, which every Pages site of that owner shares; a custom domain gives the site passkeys of its own.

## The workflow

`.github/workflows/static-site.yml` runs on pull requests, on pushes to `master` and by hand (`workflow_dispatch`). It builds the dev image, builds the Zig runtime (cached, as in ci.md), runs `scripts/static-site` in the image, and uploads `site/` with `actions/upload-pages-artifact`. The artifact, `github-pages`, is a tar of the site, kept for 7 days and downloadable from the run's page. On `master` the `deploy` job then publishes it with `actions/deploy-pages`.

The backend URL, `https://manabase.astrobunny.net/api/v1`, is set in the workflow.

## GitHub Pages setup

Done once, for https://manafe.astrobunny.net:

1. Settings > Pages > Source: GitHub Actions.
2. DNS: a `CNAME` record from `manafe.astrobunny.net` to `davidsiaw.github.io`.
3. Settings > Pages > Custom domain: `manafe.astrobunny.net`, then Enforce HTTPS once the certificate is issued. A deploy from Actions ignores `CNAME` files, so the domain lives only in this setting.
4. Configure the backend (https://manabase.astrobunny.net) as above. The mobile frontend is at https://manamo.astrobunny.net, so the backend's `FRONTEND_HOSTS` is `https://manafe.astrobunny.net,https://manamo.astrobunny.net` and `WEBAUTHN_RP_ID` is `astrobunny.net`.

Pages deployed from an artifact are not processed by Jekyll, so no `.nojekyll` file is needed.
