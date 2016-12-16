defmodule Cog.Events.Util do
  @moduledoc """
  Various utility functions used for generating event data.
  """

  @typedoc "Unique correlation ID"
  @type correlation_id :: String.t

  @doc "Microseconds between `start_time` and `current_time`."
  def elapsed(start_time, current_time) do
    DateTime.to_unix(current_time, :microseconds) -
    DateTime.to_unix(start_time, :microseconds)
  end

  @doc """
  Generate a unique identifier for use as a correlation ID for events
  from the same source (e.g., from the same HTTP request, the same
  chat command pipeline execution, etc.)
  """
  @spec unique_id() :: identifier()
  def unique_id,
    do: UUID.uuid4(:hex)

end
