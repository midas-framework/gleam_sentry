//// https://develop.sentry.dev/sdk/unified-api/
////
////

import gleam/atom
import gleam/base
import gleam/bit_string
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/uri
import gleam/beam
import gleam/http
import gleam/httpc
import gleam/json

external fn compress(String) -> String =
  "zlib" "compress"

const sentry_version = 7

const sentry_client = "sentry_gleam/0.1"

/// A Client is the part of the SDK that is responsible for event creation. 
/// To give an example, the Client should convert an exception to a Sentry event. 
/// The Client should be stateless, it gets the Scope injected and delegates the work of sending the event to the Transport.
pub type Client {
  Client(
    host: String,
    // This is the public_key, the secret_key is deprecated
    key: String,
    project_id: String,
    // I can't see any reason not to make environment required, and it should not vary by scope.
    environment: String,
  )
}

// pub type Option{
//   Environment(String)
// }
// Maybe scope has environment
fn auth_header(key, timestamp) {
  string.concat([
    "Sentry sentry_version=",
    int.to_string(sentry_version),
    ", sentry_client=",
    sentry_client,
    ", sentry_timestamp=",
    int.to_string(timestamp),
    ", sentry_key=",
    key,
  ])
}

/// Initialise a Sentry client with a DSN and environment.
pub fn init(dsn, environment) {
  try client = case uri.parse(dsn) {
    Ok(uri.Uri(userinfo: Some(key), host: Some(host), path: path, ..)) -> {
      try project_id = case string.split_once(path, "/") {
        Ok(tuple("", project_id)) -> Ok(project_id)
        _ -> Error(Nil)
      }
      Ok(Client(host, key, project_id, environment))
    }
    _ -> Error(Nil)
  }
  Ok(client)
}

// pub fn capture_event() {
// }
// Theres probably a datastructure here that does a job for level + exception + etc
// client can have an a -> event function
/// capture an erlang runtime exception
pub fn capture_exception(client, exception, stacktrace, timestamp) {
  let Client(host, key, project_id, environment) = client
  let event =
    json.object([
      // tuple("id"),
      tuple("timestamp", json.int(timestamp)),
      tuple("environment", json.string(environment)),
      tuple("exception", exception_to_json(exception, stacktrace)),
      tuple("platform", json.string("gleam")),
    ])

  let path = string.concat(["/api/", project_id, "/store/"])
  let body =
    base.encode64(bit_string.from_string(compress(json.encode(event))), False)
  let request =
    http.default_req()
    |> http.set_method(http.Post)
    |> http.set_scheme(http.Https)
    // https://e3b301fb356a4e61bebf8edb110af5b3@o351506.ingest.sentry.io/5574979
    |> http.set_host(host)
    |> http.set_path(path)
    |> http.prepend_req_header("content-type", "application/json")
    |> http.prepend_req_header("x-sentry-auth", auth_header(key, timestamp))
    |> http.prepend_req_header("user-agent", "sentry_gleam/1")
    |> http.prepend_req_header("accept", "applicaton/json")
    |> http.set_req_body(body)
  httpc.send(request)
}

fn exception_detail(reason) {
  case reason {
    beam.Badarg -> tuple("badarg", "")
    beam.Badarith -> tuple("badarith", "")
    beam.Badmatch(term) -> tuple("badmatch", beam.format(term))
    beam.FunctionClause -> tuple("function_clause", "")
    beam.CaseClause(term) -> tuple("case_clause", beam.format(term))
    beam.IfClause -> tuple("if_clause", "")
    beam.TryClause(term) -> tuple("try_clause", beam.format(term))
    beam.Undef -> tuple("undef", "")
    beam.Badfun(term) -> tuple("badfun", beam.format(term))
    beam.Badarity(term) -> tuple("badarity", beam.format(term))
    beam.TimeoutValue -> tuple("timeout_value", "")
    beam.Noproc -> tuple("noproc", "")
    beam.Nocatch(term) -> tuple("nocatch", beam.format(term))
    beam.SystemLimit -> tuple("system_limit", "")
  }
}

fn exception_to_json(exception, stacktrace) {
  let detail = exception_detail(exception)
  json.object([
    tuple("type", json.string(detail.0)),
    tuple("value", json.string(detail.1)),
    tuple("stacktrace", stacktrace_to_json(stacktrace)),
  ])
}

fn stacktrace_to_json(stacktrace) {
  let frames =
    json.list(list.map(list.reverse(stacktrace), stack_frame_to_json))
  json.object([tuple("frames", frames)])
}

fn stack_frame_to_json(frame) {
  let tuple(module, function, arity, filename, line_number) = frame
  let function = string.join([function, int.to_string(arity)], "/")
  json.object([
    tuple("filename", json.string(filename)),
    tuple("function", json.string(function)),
    tuple("module", json.string(atom.to_string(module))),
    tuple("lineno", json.int(line_number)),
  ])
}
