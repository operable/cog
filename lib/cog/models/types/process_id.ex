defmodule Cog.Models.Types.ProcessId do

  @behaviour Ecto.Type

  def type, do: :string

  def cast(value) when is_pid(value) do
    try do
      {:ok, pid_to_string(value)}
    rescue
      _e in ErlangError ->
        :error
    end
  end
  def cast(_), do: :error

  def load(value) when is_binary(value), do: {:ok, string_to_pid(value)}

  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_), do: :error

  defp pid_to_string(p) do
    String.Chars.to_string(:erlang.pid_to_list(p))
  end

  defp string_to_pid(p) do
    :erlang.list_to_pid(String.to_charlist(p))
  end

end
