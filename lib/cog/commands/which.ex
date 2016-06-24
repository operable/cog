defmodule Cog.Commands.Which do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Models.Command
  alias Cog.Queries
  alias Cog.Repo

  @description "Determine whether a given input is a command or an alias"

  @moduledoc """
  #{@description}

  Returns the type of input and it's bundle or visibility. In the case
  of aliases it also returns the aliased command string. This command
  is only useful non fully qualified commands or aliases. Fully
  qualified commands or aliases will return no match.

  Note: If a command is shadowed, it has an alias with the same name, the alias
  will be returned.

  USAGE
    which [alias]

  EXAMPLE
    which my-awesome-alias
    > alias - user:my-awesome-alias -> "echo my awesome alias"

    which an-awesome-command
    > command - operable:an-awesome-command

    which not-anything
    > No matching commands or aliases.
  """

  rule "when command is #{Cog.embedded_bundle}:which allow"

  def handle_message(req, state) do
    results = with {:ok, [arg]} <- Helpers.get_args(req.args, count: 1),
                   user_id = req.user["id"],
                   do: which(user_id, arg)

    case results do
      {:ok, data} ->
        {:reply, req.reply_to, "which", data, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  # First we determine whether or not the input is an alias. If it is we return
  # immediately. If it isn't we check to see if the input is a command.
  # Note: If an alias shadows a command the alias will be returned, not the
  # command.
  defp which(user_id, arg) do
    case Helpers.get_command_alias(user_id, arg) do
      nil ->
        case Repo.get_by(Command, name: arg) do
          nil ->
            {:ok, %{not_found: true}}
          %Command{} ->
            bundle = Queries.Command.bundle_for(arg)
            |> Repo.one!
            {:ok, %{type: "command", scope: bundle, name: arg}}
        end
      %UserCommandAlias{pipeline: pipeline} ->
        {:ok, %{type: "alias", scope: "user", name: arg, pipeline: pipeline}}
      %SiteCommandAlias{pipeline: pipeline} ->
        {:ok, %{type: "alias", scope: "site", name: arg, pipeline: pipeline}}
    end
  end
end
