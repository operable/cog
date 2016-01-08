defmodule Cog.Service.Helper do
  require Logger
  @doc """
  This is used in the AWS services to format the erlang output generated from erlcloud
  """

  @date_format "~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B"

  def format_entries([{_k, _v}|_] = list) do
    for {k, v} <- list, into: %{} do
      {format_entries(k), format_entries(v)}
    end
  end
  def format_entries({{year, month, day}, {hour, minute, second}}) do
    :erlang.iolist_to_binary(:io_lib.format(@date_format, [year, month, day, hour, minute, second]))
  end
  def format_entries([item|_] = list) when is_list(item) do
    for item <- list do
      format_entries(item)
    end
  end
  def format_entries(char_list) when is_list(char_list) do
    to_string(char_list)
  end
  def format_entries(scalar) when is_integer(scalar) or is_float(scalar) or is_atom(scalar) or is_bitstring(scalar), do: scalar
end
