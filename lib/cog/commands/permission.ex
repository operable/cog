defmodule Cog.Commands.Permission do
  alias Cog.Commands.Helpers

  def error(:invalid_permission),
    do: "Only permissions in the `site` namespace can be created or deleted; please specify permission as `site:<NAME>`"
  def error(:wrong_type),
    do: "Arguments must be strings"
  def error(error),
    do: Helpers.error(error)
end
