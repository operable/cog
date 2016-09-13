defmodule Cog.Util.Colors do

  @external_resource "priv/css-color-names.json"

  hex_codes = File.read!(@external_resource) |> Poison.decode!
  names = Enum.reduce(hex_codes, %{}, fn({name, code}, acc) -> Map.put(acc, code, name) end)

  def name_to_hex(<<?#, _::binary>>=color), do: color
  Enum.each(hex_codes, fn({name, value}) ->
    def name_to_hex(unquote(name)), do: unquote(value)
  end)
  def name_to_hex(_), do: :unknown_color

  Enum.each(names, fn({code, name}) ->
    def hex_to_name(unquote(code)), do: unquote(name)
  end)
  def hex_to_name(_), do: :unknown_color

  def names(), do: unquote(Enum.sort(Map.keys(hex_codes)))

end
