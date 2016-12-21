defmodule Cog.Events.ApiEvent do
  @moduledoc """
  Encapsulates information about REST API request processing
  events. Each event is a map; all events share a core set of fields,
  while each event sub-type will have an additional set of fields
  particular to that sub-type.

  The functions in this module generate API events from `Plug.Conn`
  instances, and depend on various metadata having been added to the
  `Conn` beforehand; see `Cog.Plug.Util` and `Cog.Plug.Event`

  # Common Fields

  * `request_id`: The unique identifier assigned to the request. All
    events emitted in the processing of the request will share the
    same ID.

  * `event`: label indicating which API request lifecycle event is
    being recorded.

  * `timestamp`: When the event was created, in UTC, as an ISO-8601
    extended-format string (e.g. `"2016-01-07T15:08:00.000000Z"`). For
    pipelines that execute in sub-second time, also see
    `elapsed_microseconds`.

  * `elapsed_microseconds`: Number of microseconds elapsed since
    beginning of request processing to the creation of this event.

  * `http_method`: the HTTP method of the request being processed as
    an uppercase string.

  * `path`: the path portion of the request URL

  # Event-specific Data

  Depending on the type of event, the map will contain additional
  different keys. These are detailed here for each event.

  ## `api_request_started`

  No extra fields

  ## `api_request_authenticated`

  * `user`: (String) the Cog username of the authenticated
    requestor. Note that this is not a chat handle.

  ## `api_request_finished`

  * `status`: (Integer) the HTTP status code of the response.
  """

  alias Plug.Conn

  import Cog.Events.Util, only: [elapsed: 2]
  import Cog.Plug.Util, only: [get_request_id: 1,
                               get_start_time: 1,
                               get_user: 1]

  @type event_label :: :api_request_started |
                       :api_request_authenticated |
                       :api_request_finished

  @doc "Create an `api_request_started` event."
  def started(%Conn{}=conn),
    do: new(conn, :api_request_started)

  @doc "Create an `api_request_started` event."
  def authenticated(%Conn{}=conn) do
    # Should never be called if there's no user set
    new(conn, :api_request_authenticated, %{user: get_user(conn).username})
  end

  @doc "Create an `api_request_started` event."
  def finished(%Conn{}=conn),
    do: new(conn, :api_request_finished, %{status: conn.status})

  # Centralize common event creation logic
  defp new(conn, event, extra_fields \\ %{}) do
    start = get_start_time(conn)
    {now, elapsed_us} = case event do
                          :api_request_started -> {start, 0}
                          _ ->
                            now = DateTime.utc_now()
                            {now, elapsed(start, now)}
                        end

    Map.merge(extra_fields,
              %{request_id: get_request_id(conn),
                http_method: conn.method,
                path: conn.request_path,
                event: event,
                timestamp: Calendar.ISO.to_string(now),
                elapsed_microseconds: elapsed_us})
  end

end
