defmodule Cog.Command.Helpers do

  def add_errors(input, error_or_errors),
    do: Map.update!(input, :errors, &Enum.concat(&1, List.wrap(error_or_errors)))
end
