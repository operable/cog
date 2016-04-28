defmodule Carrier.Util do

  @doc "Converts an integer to the given base"
  @spec convert_integer(integer(), pos_integer()) :: integer()
  def convert_integer(value, to_base) do
    istr = Integer.to_string(value, to_base)
    String.to_integer(istr, to_base)
  end

  @doc "Converts a binary into a hexadecimal string"
  @spec binary_to_hex_string(binary()) :: String.t()
  def binary_to_hex_string(bin),
    do: Base.encode16(bin)

  @doc "Converts a hexadecimal string to an equivalent Erlang binary"
  @spec hex_string_to_binary(String.t()) :: binary()
  def hex_string_to_binary(text) do
    {:ok, bin} = Base.decode16(text)
    bin
  end

end
