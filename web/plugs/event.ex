defmodule Cog.Plug.Event do
  @moduledoc """
  Core functionality of the REST API event instrumentation.

  This plug should be placed at the beginning of a Phoenix processing
  pipeline, as it sets some data in the request that is used
  throughout API processing for sending events.

  First, it stamps the request with a timestamp, from which all other
  events emitted in the course of processing will report the amount of
  time elapsed.

  Second, it adds a unique request ID. This is distinct from the one
  added by `Plug.RequestId`; we chose not to use that plug and instead
  rolled our own in order to ensure that all correlation IDs used
  across all our events (not just those from the API) had the same
  structure.

  The plug will emit an `api_request_started` event, and will ensure
  that an `api_request_finished` event will be emitted at the end of
  processing (via a callback function).

  Other events may be emitted through the course of request
  processing, but they require the data added by this plug.
  """

  @behaviour Plug

  alias Plug.Conn
  alias Cog.Events.ApiEvent

  import Cog.Plug.Util, only: [stamp_start_time: 1,
                               stamp_request_id: 1]

  # Nothing to configure
  def init(_opts),
    do: :ok

  def call(conn, :ok) do
    # Set key data for the request that all events will use
    conn = conn |> stamp_start_time |> stamp_request_id

    # Emit started event
    conn |> ApiEvent.started |> Probe.notify

    # Ensure finished event will be emitted
    Conn.register_before_send(conn, fn(conn) ->
      conn |> ApiEvent.finished |> Probe.notify
      conn
    end)
  end

end
