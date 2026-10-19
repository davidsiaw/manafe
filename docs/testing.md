# Testing

There are two test suites and a build check. Each has a wrapper in `scripts/`, and the wrapper is the only entry point, whether you run it locally, in the container or in CI.

| Suite | Wrapper | What it tests | What it needs |
|---|---|---|---|
| Capybara/Selenium | `scripts/rspec [files] [rspec args]` | The real SPA in a real Chromium, against a mock backend | A Selenium Grid |
| OJTest | `scripts/ojtest [files]` | Pure-logic Objective-J, run in Node | `ojtest` from the npm package `@objj/cappuccino` |
| Build check | `scripts/build` | That `chino build` succeeds | `jake` from the same npm package |

```sh
heighliner up                       # the container holds a copy of the source, so rebuild first
heighliner login rspec
heighliner login rspec tests/spec/course_spec.rb -e 'ticks the problem'
heighliner login ojtest
heighliner login build
```

Running them from the pi sandbox, without rebuilding, is described in heighliner.md. To watch the browser while specs run, connect a VNC client to port 5900 on the host (the shared chrome container).

## Browser specs: how they are wired

- The test gems live in their own bundle, `tests/Gemfile`, which also has `chino` and `puma`. The lockfile lists Linux and macOS platforms; keep them when you update it.
- **The specs serve the app themselves.** `spec_helper.rb` mounts chino's Sinatra app (`Chino::Website`) at `/` and `MockApi` at `/api/v1`, and Capybara runs both on puma on `0.0.0.0:$TEST_PORT` (4445; in the container the dev server's chino holds 4444, and as the container's main process it cannot be restarted with test settings).
- `spec_helper.rb` sets `API_BASE_URL=/api/v1`, and `Config.j.erb` is rendered per request from the spec process's environment, so the SPA calls the mock on its own origin: no CORS, no preflight.
- The browser is remote, at `http://$CHROME_HOSTNAME:4444/wd/hub`. It loads the app from `http://manabase-test:$TEST_PORT`: chrome maps that name to `TEST_HOST` (`--host-resolver-rules`) and treats the origin as secure (`--unsafely-treat-insecure-origin-as-secure`). Passkeys need a domain name, which `TEST_HOST` may not be (it is an IP address in the sandbox), and a secure origin. The chrome container resolves `TEST_HOST`, so it is never `127.0.0.1`.
- Specs run in random order; write `RSpec.describe`.

## Browser specs: helpers

**The mock backend** (`tests/mock_api.rb`), reset before each example:

- `MOCK_API.stub('GET', '/courses/sample', status: 200, body: {...})` queues a response. Each request takes the next response for its method and path, in FIFO order, so queue one per request the app will make, in order. A request with nothing queued gets status 599 and an error body naming the missing stub.
- `MOCK_API.requests_to('POST', '/login')` returns the requests made, each with `headers['Authorization']` and the parsed JSON `body`.
- `progress(solved:, revision:, times_solved:, times_completed:)` (`tests/course_helper.rb`) builds a progress response in the backend's shape.

**The browser's state before the app boots** (`tests/learner_helper.rb`). `localStorage` is per origin, so these write it from a page on the app's origin that is not the app (`/api/v1/blank`; loading the app would already create a learner):

- `visit_as_anonymous(path, courses: [])` and `visit_as_registered(path, email:)` also queue the `GET /me` the app makes at startup. A screen that calls `GET /me` itself (My progress) needs a second one.
- `prepare_browser(token:, email:, has_logged_in:)` for anything else.
- `local_storage('manabase.token')` reads a key.

**Passkeys** (`tests/passkey_helper.rb`): `add_virtual_authenticator` gives chrome a virtual authenticator (removed after each example), and `registration_options(email, user_id:)` and `login_options` build the options the backend would send, with `manabase-test` as the relying party. The virtual authenticator then really creates and uses passkeys; only the backend's verification is mocked. `base64url(bytes)` encodes like the backend.

**Talking to Cappuccino, not the DOM** (`tests/cappuccino_helper.rb`). Cappuccino renders absolutely positioned divs, which Capybara's matchers handle badly, so the helpers walk the view hierarchy with `objj_msgSend`:

- `wait_for_cappuccino` first, always: the runtime loads asynchronously.
- `wait_for_cappuccino_text(str)`, `wait_for_cappuccino_text_including(str)` and `cappuccino_text_values` read `CPTextField`s, including those in popovers and alerts.
- `wait_for_cappuccino_button(title)`, `cappuccino_button_visible?(title)` and `click_cappuccino_button(title)`. Clicking sends the action to the target; it does not change a checkbox's state (cappuccino.md).
- `choose_cappuccino_radio(title)` and `cappuccino_selected_radio_titles`.
- `cappuccino_outline_rows` and `wait_for_cappuccino_outline_row(text)` read the visible rows of an outline view as its data source renders them.
- `fill_cappuccino_field(placeholder, value)` types into the editable field with that placeholder.

Add new helpers to that file, built on `VIEW_WALK_JS`, rather than writing JavaScript in specs.

## Browser specs: gotchas

- Do not use `have_text` or `page.text` after the UI has been rebuilt: Selenium's visible text can come back as just `"x"` (Cappuccino's text-measuring span). Use the helpers. `have_title` and `have_current_path(..., url: true)` are fine.
- Queue stubs **before** the action that makes the request. A stub added after `visit` races the app.
- A screen built twice makes its requests twice and uses up stubs meant for later. If a spec fails with a 599, look for double navigation (architecture.md).
- If a simple smoke check fails, suspect the harness before the app: that chrome is reachable and that `TEST_HOST` is right.

## Unit tests

Unit tests in `tests/unit/` cover the pure-logic files (`Router`, `AuthStore`, `Passkeys`, `CourseTree`, `TextFormat`). They run in Node with the Objective-J runtime and Foundation: no DOM, no AppKit, no `XMLHttpRequest`. `SanityTest.j` is a canary for the toolchain. Node has `atob`/`btoa`, which `Passkeys.j` uses.

| Belongs in tests/unit | Belongs in tests/spec |
|---|---|
| State machines, parsers, formatters, conversions | Anything that needs the SPA rendered |
| Helpers that do not touch browser globals | Anything that talks to a server; end-to-end flows |

Do not add jsdom or stub out browser globals to make a test fit in `tests/unit`. Inject what a class needs instead, as `AuthStore` takes its storage.

ojtest's silent rules:

- The class name must match the file name (`FooTest.j` defines `FooTest : OJTestCase`), or ojtest prints "unable to get tests" and `Total tests: 0`.
- Methods starting with `test` run; `setUp` and `tearDown` work as in XCTest; assertions are class methods on `OJAssert` (`assert:equals:`, `assertTrue:`, `assertFalse:`). `assert:equals:` compares arrays by content but tells `null` from `undefined`.
- Import the code under test by relative path: `@import "../../Foo.j"`.

The unit test files are not part of the app, but `chino build` would compile them; `scripts/build` hides `tests/` during the build (chino.md).

## The wrapper scripts

`scripts/ojtest` is itself called `ojtest` and is on PATH in the image, so it finds the real binary by skipping its own directory. It prints what it runs first, because ojtest is silent for seconds on a cold start. `scripts/rspec` checks that `CHROME_HOSTNAME` and `TEST_HOST` are set; Heighliner.config sets both in the container and CI passes them to `docker run`. AppKit takes a few seconds to boot from cold, which is why `Capybara.default_max_wait_time` is 15 seconds.

## End to end

These specs never touch the real backend, and the backend's specs never touch this app. After changing anything the two share (an endpoint's shape, the WebAuthn data), check them together: start both, open `https://manafe.<suffix>`, and go through the affected flow. Passkey flows can be driven from the sandbox with a Selenium script against the real HTTPS site: chrome options `--ignore-certificate-errors`, then `driver.add_virtual_authenticator(Selenium::WebDriver::VirtualAuthenticatorOptions.new(protocol: :ctap2, transport: :internal, resident_key: true, user_verification: true, user_verified: true))`, then drive the app with the same JavaScript the helpers use.
