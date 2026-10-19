# heighliner (local development)

heighliner runs the app container. It used to be called kaiser, and the `kaiser` command and `Kaiserfile` name still work. The pi sandbox has no docker socket, so there the `heighliner` command is forwarded to a spice server. The `heighliner` skill covers the general rules; this file covers what is specific to this repo.

## This project

- The environment is called `manafe` on the original machine, and the backend's `manabe`; Heighliner.config assumes the backend's name (below). On another machine, find a project's name with `heighliner init x`: in a project that is already initialised, it refuses, prints the existing name and changes nothing.
- The app container is `<env>-app` and serves on port 4444. Through the proxy the app is at `https://<env>.<suffix>`, where `<suffix>` is whatever `heighliner show http-suffix` prints. The suffix differs between installs, so never assume one. Plain `http://` may redirect to `https://`.
- The source is copied into the image, not bind-mounted. After you edit anything, run `heighliner up` to rebuild before testing in the container.
- The SPA reaches the backend at `API_BASE_URL`, which Heighliner.config sets to `https://manabe.<suffix>/api/v1`. That assumes `../backend` was initialised as `heighliner init manabe`. Start the backend with its own `heighliner up` first.
- `heighliner login <cmd>` runs a command inside `<env>-app`. `/app/scripts` is on PATH there, so `heighliner login rspec`, `heighliner login ojtest` and `heighliner login build` all work. When you call these from a script, redirect stdin from `/dev/null`.

## Heighliner.config is an ERB template

heighliner renders `app_params`, the database strings and the Dockerfile with `ERB.new(value).result(binding)` on its CLI object. The useful names in scope are `app_container_name`, `envname`, `http_suffix`, `app_expose`, `db_container_name` and `@config[:shared_names][:chrome]`. The last one is the shared Selenium container. It is called `heighliner-chrome` on a fresh install and `kaiser-chrome` on hosts upgraded from kaiser, so never hardcode it. Heighliner.config uses these names to pass `CHROME_HOSTNAME` and `TEST_HOST` into the container.

The Dockerfile deliberately contains no ERB, because CI builds it with plain `docker buildx`.

## Known noise and flakes

- Every command prints `fatal: detected dubious ownership in repository`. The message comes from git on the spice server and is harmless; the branch name still resolves.
- `heighliner up` sometimes fails with `- exited with code 125` on the final `docker run`, when it is replacing a running container. Running `up` again has fixed it every time so far. `heighliner up -v` prints more detail.
- `heighliner logs` follows the log and never returns, so wrap it as `timeout 15 heighliner logs`.

## Running specs directly from the pi sandbox

The sandbox is on the same docker network as heighliner, so you can run the specs without the app container. This is faster when iterating on uncommitted code, because the container only has the copy of the source from the last build.

```sh
bundle install
# The shared chrome container's name depends on the install; use whichever resolves.
CHROME_HOSTNAME=$(for h in heighliner-chrome kaiser-chrome; do getent hosts $h >/dev/null && echo $h && break; done)
TEST_HOST=$(hostname -I | awk '{print $1}') CHROME_HOSTNAME=$CHROME_HOSTNAME scripts/rspec
```

The specs serve the app from the spec process on port 4445 (see testing.md), so nothing else needs to be running. The sandbox's IP address works as `TEST_HOST` even for the passkey specs, because chrome reaches the app as `manabase-test`, mapped to that address. `TEST_HOST` must be an address the chrome container can reach. The sandbox's hostname is not in heighliner's DNS, but its IP address is reachable.

To run ojtest in the sandbox, run `npm install --prefix /tmp/capp @objj/cappuccino` and add `/tmp/capp/node_modules/.bin` to PATH.

Be careful with `pkill -f chino` in the sandbox. The project path contains "chino", so the command also kills your own shell. Use `pkill -f 'bundle exec chino'` instead.
