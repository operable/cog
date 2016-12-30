defmodule Cog.Test.Util do
  @moduldoc """
  Collection of utility functions for use in tests
  """

  @doc """
  unwraps 2-tuples starting with the provided value
  """
  def unwrap(tuple, any \\ :ok)
  def unwrap({any, value}, any), do: value
  def unwrap(any, value),
    do: raise "Expected 2-tuple starting with #{inspect any} but received #{inspect value} instead."

  @doc """
  unwraps :error tuples, returning just the error
  If a tuple without an :error atom is passed, raises an error.
  """
  def unwrap_error(value),
    do: unwrap(value, :error)

end
