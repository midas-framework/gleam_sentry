import gleam/os
import gleam/io
import gleam_sentry
import gleam_uuid
import gleam/should

pub fn sending_spans_test() {
  assert Ok(client) =
    gleam_sentry.init(
      "https://e3b301fb356a4e61bebf8edb110af5b3@o351506.ingest.sentry.io/5574979",
      "local",
    )

  let trace_id =
    gleam_uuid.v4()
    |> gleam_uuid.format(gleam_uuid.Hex)
    |> io.debug

  gleam_sentry.capture_trace(client, trace_id, Nil, os.system_time(os.Second))
  |> io.debug
  todo
}
