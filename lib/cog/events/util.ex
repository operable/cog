defmodule Cog.Events.Util do
  @moduledoc """
  Various utility functions used for generating event data.
  """

  # ISO-8601 UTC
  @date_format "~.4.0w-~.2.0w-~.2.0wT~.2.0w:~.2.0w:~.2.0wZ"

  @typedoc "Unique correlation ID"
  @type correlation_id :: String.t

  @doc """
  Current time, as an ISO-8601 formatted string.

  Example:

      iex> Cog.Events.Util.now_iso8691_utc
      "2016-01-15T01:48:20Z"

  """
  @spec now_iso8601_utc() :: binary()
  def now_iso8601_utc do
    {{year, month, day}, {hour, min, sec}} = :calendar.universal_time
    :io_lib.format(@date_format, [year, month, day, hour, min, sec])
    |> IO.iodata_to_binary
  end

  @doc "Current time as an Erlang timestamp."
  @spec now() :: :erlang.timestamp()
  def now,
    do: :os.timestamp

  @doc "Microseconds between `start_time` and now."
  @spec elapsed(:erlang.timestamp()) :: integer()
  def elapsed(start_time),
    do: :timer.now_diff(now, start_time)

  @doc """
  Generate a unique identifier for use as a correlation ID for events
  from the same source (e.g., from the same HTTP request, the same
  chat command pipeline execution, etc.)
  """
  @spec unique_id() :: identifier()
  def unique_id,
    do: UUID.uuid4(:hex)

end
