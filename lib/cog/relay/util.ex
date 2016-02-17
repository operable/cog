defmodule Cog.Relay.Util do

  @doc "Converts an integer to the given base"
  @spec convert_integer(integer(), pos_integer()) :: integer()
  def convert_integer(value, to_base) do
    istr = Integer.to_string(value, to_base)
    String.to_integer(istr, to_base)
  end

  @doc "Return true if tuple has an :ok status"
  def is_ok?({:ok, _}), do: true
  def is_ok?({_,_}), do: false

  @doc "Returns the data that is wrapped in a tuple"
  def unwrap_tuple({_status, bundle_data}), do: bundle_data

  @doc "Given a tuple containing tuples with both :ok and :error statuses,
  return a tuple containing lists of the separated items"
  def unwrap_partition_results({oks, errors}) do
    {Enum.map(oks, &unwrap_tuple/1),
     Enum.map(errors, &unwrap_tuple/1)}
  end

end
