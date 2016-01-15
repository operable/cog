defmodule Cog.Events.ApiEvent do
  @moduledoc """
  Provides functions for generating REST API request processing
  events.

  The functions in this module generate API events from `Plug.Conn`
  instances, and depend on various metadata having been added to the
  `Conn` beforehand; see `Cog.Plug.Util` and `Cog.Plug.Event`
  """

  alias Plug.Conn

  import Cog.Events.Util, only: [elapsed: 1,
                                 now_iso8601_utc: 0]
  import Cog.Plug.Util, only: [get_request_id: 1,
                               get_start_time: 1,
                               get_user: 1]

  @type event_label :: :api_request_started |
                       :api_request_authenticated |
                       :api_request_finished
  @typedoc """
  Encapsulates information about REST API request processing events.

  # Fields

  * `request_id`: The unique identifier assigned to the request. All
    events emitted in the processing of the request will share the
    same ID.

  * `event`: label indicating which API request lifecycle event is
    being recorded.

  * `timestamp`: When the event was created, in UTC, as an ISO-8601
    extended-format string (e.g. `"2016-01-07T15:08:00Z"`). For
    pipelines that execute in sub-second time, also see
    `elapsed_microseconds`.

  * `elapsed_microseconds`: Number of microseconds elapsed since
    beginning of request processing to the creation of this event. Can
    be used to order events from a single request.

  * `http_method`: the HTTP method of the request being processed as
    an uppercase string.

  * `path`: the path portion of the request URL

  * `data`: Map of arbitrary event-specific data. See below for
    details.

  # Event-specific Data

  Depending on the type of event, the `data` map will contain
  different keys. These are detailed here for each event.

  ## `api_request_started`

  No extra data

  ## `api_request_authenticated`

  * `user`: (String) the Cog username of the authenticated
    requestor. Note that this is not a chat handle.

  ## `api_request_finished`

  * `status`: (Integer) the HTTP status code of the response.

  """
  @type t :: %__MODULE__{request_id: Cog.Events.Util.correlation_id(),
                         event: event_label(),
                         timestamp: String.t,
                         elapsed_microseconds: non_neg_integer(),
                         http_method: String.t,
                         path: String.t,
                         data: map()}
  defstruct [request_id: nil,
             event: nil,
             timestamp: nil,
             elapsed_microseconds: 0,
             http_method: nil,
             path: nil,
             data: %{}]

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
  defp new(conn, event, data \\ %{}) do
    %__MODULE__{request_id: get_request_id(conn),
                http_method: conn.method,
                path: conn.request_path,
                event: event,
                timestamp: now_iso8601_utc,
                elapsed_microseconds: case event do
                                        :api_request_started -> 0
                                        _ -> elapsed(get_start_time(conn))
                                      end,
                data: data}
  end

end
