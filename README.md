# Manabase frontend

The app students use in Manabase, a base system for interactive learning modules: a course menu, courses shown as a collapsible problem tree with a problem beside it, multiple choice exercises, passkey accounts, a personal progress page, and revision mode for going through a course again. Everything it shows comes from the backend repository, normally checked out next to this one.

A [Cappuccino](https://www.cappuccino.dev) (Objective-J) single-page app, served and built by [chino](https://github.com/davidsiaw/chino), and started from the chino-base template.

## Running it

Start the backend first (`../backend`), then:

```sh
heighliner init manafe     # once
heighliner up
open "https://manafe.$(heighliner show http-suffix)"
```

## Testing

```sh
heighliner up              # the container holds a copy of the source
heighliner login rspec     # browser specs, against a mock backend
heighliner login ojtest    # unit tests
heighliner login build     # the release build
```

## Documentation

How the app is built, how it talks to the backend, accounts and passkeys, the course screen and revision mode, Cappuccino pitfalls, and testing: [docs/](docs/README.md). Start with [docs/system.md](docs/system.md).
