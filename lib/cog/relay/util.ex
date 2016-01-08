defmodule Cog.Relay.Util do

  @doc "Converts an integer to the given base"
  @spec convert_integer(integer(), pos_integer()) :: integer()
  def convert_integer(value, to_base) do
    istr = Integer.to_string(value, to_base)
    String.to_integer(istr, to_base)
  end

end
