defmodule Cog.Formatters.JSON do
  def format(data) do
    encode(data, 0)
  end

  defp encode({key, value}, level) when is_map(value) or is_list(value) do
    "#{indent(level)}#{key}: #{String.lstrip(encode(value, level))}"
  end
  defp encode({key, value}, level) do
    "#{indent(level)}#{key}: #{encode(value, 0)}"
  end
  defp encode(item, level) when is_map(item) do
    String.rstrip """
    #{indent(level)}{
    #{Enum.map(item, &(encode(&1, level + 1))) |> Enum.join(",\n")}
    #{indent(level)}}
    """
  end
  defp encode(item, level) when is_list(item) do
    String.rstrip """
    #{indent(level)}[
    #{Enum.map(item, &(encode(&1, level + 1))) |> Enum.join(",\n")}
    #{indent(level)}]
    """
  end
  defp encode(item, level) do
    "#{indent(level)}#{item}"
  end

  defp indent(level) do
    repeat_string("\t", level)
  end

  defp repeat_string(string, times) do
    repeat_string(string, times, "")
  end

  defp repeat_string(_, 0, acc) do
    acc
  end
  defp repeat_string(string, times, acc) do
    repeat_string(string, times - 1, acc <> string)
  end
end
