defmodule Cog.Config do

  @doc """
  Token lifetime configuration, converted into seconds. This is how
  long after creation time a token is considered valid.
  """
  def token_lifetime do
    value = Application.fetch_env!(:cog, :token_lifetime)
    convert(value, :sec)
  end

  @doc """
  Token reap period configuration, converted into
  milliseconds. Expired tokens will be reaped on this schedule.
  """
  def token_reap_period do
    value = Application.fetch_env!(:cog, :token_reap_period)
    convert(value, :ms)
  end

  @doc """
  Convert various tagged time durations into either seconds or
  milliseconds, as desired.

  Useful for allowing a readable configuration format that can still
  easily be translated into the time units most frequently encountered
  in Elixir / Erlang code.

  More general conversion (e.g., from days to minutes), or using
  variable conversion units (i.e., a month can have 28, 29, 30, or 31
  days in it, depending on the month and/or year) are explicitly not
  handled.

  Units are specified as one of the following recognized atoms:

  - :ms (millisecond)
  - :sec (second)
  - :min (minute)
  - :hour
  - :day
  - :week

  Examples:

      iex> Cog.Config.convert({3, :day}, :sec)
      259200

  """
  def convert(from, into) do
    from
    |> convert_to_seconds
    |> convert_from_seconds(into)
  end

  defp convert_to_seconds({seconds, :sec}),
    do: {seconds, :sec}
  defp convert_to_seconds({minutes, :min}),
    do: {minutes * 60, :sec}
  defp convert_to_seconds({hours, :hour}),
    do: {hours * 60 *60, :sec}
  defp convert_to_seconds({days, :day}),
    do: {days * 24 * 60 * 60, :sec}
  defp convert_to_seconds({weeks, :week}),
    do: {weeks * 7 * 24 * 60 * 60, :sec}

  defp convert_from_seconds({seconds, :sec}, :ms),
    do: seconds * 1000
  defp convert_from_seconds({seconds, :sec}, :sec),
    do: seconds

end
