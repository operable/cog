defmodule Cog.Commands.Relay do
  require Cog.Commands.Helpers, as: Helpers

  def error(:wrong_type),
    do: "Arguments must be strings"
  def error(error),
    do: Helpers.error(error)
end
