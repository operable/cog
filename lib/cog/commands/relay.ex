defmodule Cog.Commands.Relay do
  alias Cog.Commands.Helpers

  def error(:wrong_type),
    do: "Arguments must be strings"
  def error({:relay_not_found, relay_name}),
    do: "No relay with name '#{relay_name}' could be found"
  def error(error),
    do: Helpers.error(error)
end
