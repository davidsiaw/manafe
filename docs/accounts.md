# Accounts: sessions, registering, logging in and out

What the backend does with all this is in [backend/docs/accounts.md](../../backend/docs/accounts.md). This file is the browser's side.

## Who the learner is: AuthStore

`AuthStore.j` keeps three `localStorage` keys and derives a state from them:

| Key | Holds |
|---|---|
| `manabase.token` | The session token, sent as `Authorization: Bearer <token>` |
| `manabase.email` | The email, when registered |
| `manabase.hasLoggedIn` | Set once the browser has been registered or logged in, and never cleared |

| State | Meaning | What startup does |
|---|---|---|
| `fresh` | No token, never logged in | `POST /learners`, keeps the token: now `anonymous` |
| `anonymous` | Token, no email | `GET /me` to check the session |
| `registered` | Token and email | `GET /me` to check the session |
| `loggedOut` | No token, but `hasLoggedIn` | Nothing: every screen except `#/register` asks to log in |

The `loggedOut` state is deliberate: a browser that has been used with an account does not quietly turn into an anonymous one after logout, which would be confusing. Its "You are logged out" page offers "Log in with a passkey" and "Create a new account".

When `GET /me` (or a course's progress) answers 401, the session is dropped (`-endSession`) and startup runs again, which leads to `fresh` or `loggedOut`. This happens at most once per page load (architecture.md).

`AuthStore` takes the storage object as a parameter, so its unit tests use a plain object instead of `localStorage`.

## Registering

`#/register`, `AppController -register:`:

1. With an anonymous session: `POST /registration/options {email}`. In the `loggedOut` state there is no session, so the app first creates a learner with `POST /learners`, but keeps that token only in memory until registration succeeds; giving up halfway leaves the browser logged out, not anonymous.
2. `PasskeysCreate(options)` runs `navigator.credentials.create`. The browser asks the user to create a passkey.
3. `POST /registration {credential}`. On success: `-becomeRegistered:token:`, then to `#/me`.

Error codes from the backend become messages under the form (`-registrationErrorMessage:status:`), for example `email_taken`: "That email is already registered. Log in instead."

## Logging in

From the top bar or the logged-out page, `AppController -logIn:`:

1. `POST /login/options`: a challenge with an empty `allowCredentials`, so the browser offers every passkey it has for the site (usernameless login; no email is asked for).
2. `PasskeysGet(options)` runs `navigator.credentials.get`.
3. `POST /login {credential}` returns a new token and the email: `-becomeRegistered:token:`. The anonymous session the browser had is simply replaced, and its progress is left behind on purpose.

Failures show an alert (`CPAlert`).

## Logging out

`DELETE /session`, then the token and email are removed whatever the server answered. `hasLoggedIn` stays, so the browser is now `loggedOut`.

## Passkeys.j

The backend sends WebAuthn options as JSON with binary fields in base64url, and expects the credential back the same way. The browser API wants and returns `ArrayBuffer`s. `Passkeys.j` converts:

- `PasskeysCreationOptions(json)` / `PasskeysRequestOptions(json)`: decode `challenge`, `user.id` and the ids in `excludeCredentials` / `allowCredentials`.
- `PasskeysCredentialToJSON(credential)`: encode `rawId` and the response's `clientDataJSON`, `attestationObject`, `authenticatorData`, `signature` and `userHandle`, whichever are present, plus `transports` and `clientExtensionResults`.
- `PasskeysCreate` / `PasskeysGet` run the ceremony and call back with `(credentialJSON, errorMessage)`. A `NotAllowedError` (cancelled or timed out) becomes "The passkey request was cancelled."

The newer `PublicKeyCredential.parseCreationOptionsFromJSON` and `credential.toJSON()` would replace most of this, but are not in every browser yet.

Passkeys only work on HTTPS or `localhost`, and on a domain name, not an IP address. They belong to the frontend's host: the backend's `WEBAUTHN_RP_ID` must match it.
