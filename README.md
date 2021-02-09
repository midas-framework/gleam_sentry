# gleam_sentry

Report runtime exceptions to https://sentry.io

## Usage

#### Intialise a client with your DSN and environment name.

```rust
  import gleam_sentry as sentry

  let dsn = "https://public_key@o0.ingest.sentry.io/123"
  let environment = "production"
  assert Ok(client) = sentry.init(dsn, environment)
```

#### Capture an exception

```rust
sentry.capture_exception(client, reason, stacktrace, timestamp)
```

The types for reason and stacktrace are defined in the [gleam/beam](https://github.com/midas-framework/beam) project along with cast functions that allow you to get these values form logger events.

#### Logger integration

```rust
// my_app/logger.gleam
import gleam/beam.{ExitReason, Stacktrace}

pub fn handle(client, reason: ExitReason, stacktrace: Stacktrace, timestamp) {
  sentry.capture_exception(client, reason, stacktrace, timestamp)
  Nil
}
```

```rust
// During startup
import gleam/beam/logger
import my_app/logger as my_logger

pub fn start(){
  logger.add_handler(my_logger.handle(client, _, _, _))
}
```

## Future

gleam_sentry currently reports errors from the beam runtime system, and as such could be implemented as an erlang library.
I have not used existing projects (see prior art below) as only Elixir projects are based on the new logger.

I would like this project to be useful in erlang projects.
It would also be interesting to have a more general purpose span/context/error handling framework that this could plug in to.

## Prior Art

### Raven

https://github.com/artemeff/raven-erlang

erlang project, integrates with lager and error_logger.

- Has an empty supervisor, just so it can be started as an app which adds a logger handler.
- Every capture results in a call to sentry. https://github.com/artemeff/raven-erlang/blob/master/src/raven.erl#L46
- Uses httpc and manually calls zlib. https://github.com/artemeff/raven-erlang/blob/master/src/raven.erl#L76-L86
- Has a bunch of hardcoded mappers from error types. https://github.com/artemeff/raven-erlang/blob/master/src/raven_error_logger.erl#L108-L184
  - NOTE: these are old format so not useful to reproduce

### Sparrow

https://github.com/ExpressApp/sparrow/tree/master/lib/sparrow

Elixir project, uses new logger

- Starts a coordinator and task supervisor, is this necessary with the infrastructure that already exists in logger?
- It has a Client behaviour module but only one implementation directly in the library.