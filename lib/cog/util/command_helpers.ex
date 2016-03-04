defmodule Cog.Command.Helpers do
  @moduledoc """
  These are generic Cog command helper functions that can be used when
  executing Cog commands.
  """

  @doc"""
  This function allows all errors to be collected before sending a more complete
  list of errors to the user.

  GIVEN
  - "input": a map or struct that will accept the :errors key
  - "error_or_errors": the error or errors that are to be added to the map

  RETURNS
  - A map containing the :errors key with a list of errors that were generated
  when validating key aspects of a command's input.

  EXAMPLE
    > add_errors(%{input: %{1 => "hello"}, errors: []}, {:not_string, [1]})
    %{errors: [not_string: [1]], input: %{1 => "hello"}}
  """
  def add_errors(input, error_or_errors),
    do: Map.update!(input, :errors, &Enum.concat(&1, List.wrap(error_or_errors)))
end
