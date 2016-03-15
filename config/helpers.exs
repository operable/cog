defmodule Cog.Config.Helpers do
  defmacro __using__(_) do
    quote do
      import Cog.Config.Helpers
    end
  end

  def data_dir do
    System.get_env("COG_DATA_DIR") || Path.expand(Path.join([Path.dirname(__ENV__.file), "..", "data"]))
  end

  def data_dir(subdir) do
    Path.join([data_dir, subdir])
  end

  def ensure_integer(ttl) when is_nil(ttl), do: false
  def ensure_integer(ttl) when is_binary(ttl), do: String.to_integer(ttl)
  def ensure_integer(ttl) when is_integer(ttl), do: ttl

  def ensure_boolean(nil), do: nil
  def ensure_boolean(value) when is_binary(value) do
    value
    |> String.downcase
    |> string_to_boolean
  end

  defp string_to_boolean("true"), do: true
  defp string_to_boolean(_), do: false

end
