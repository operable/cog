defmodule Cog.Commands.Group do
  alias Cog.Commands.Helpers

  def error(:wrong_type),
    do: "Arguments must be strings"
  def error({:protected_group, name}),
    do: "Cannot alter protected group #{name}"
  def error(error),
    do: Helpers.error(error)
end
