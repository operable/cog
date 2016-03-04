defmodule Cog.Commands.Which do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Models.Command
  alias Cog.Queries
  alias Cog.Repo

  @moduledoc """
  Determine whether a given input is a command or an alias. Returns the type of
  input and it's bundle or visibility. In the case of aliases it also returns
  the aliased command string. This command is only useful non fully qualified
  commands or aliases. Fully qualified commands or aliases will return no match.

  Note: If a command is shadowed, it has an alias with the same name, the alias
  will be returned.

  ## Example

    @bot #{Cog.embedded_bundle}:which my-awesome-alias
    > alias - user:my-awesome-alias -> "echo my awesome alias"

    @bot #{Cog.embedded_bundle}:which an-awesome-command
    > command - operable:an-awesome-command

    @bot #{Cog.embedded_bundle}:which not-anything
    > No matching commands or aliases.
  """

  def handle_message(req, state) do
    results = with {:ok, user} <- get_user(req.requestor),
                   {:ok, [arg]} <- Helpers.get_args(req.args, count: 1),
                     do: which(user, arg)

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
  defp which(user, arg) do
    case Helpers.get_command_alias(user, arg) do
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

  # A simple wrapper around Helpers.get_user/1. So we can get output like we
  # want it.
  defp get_user(requestor) do
    case Helpers.get_user(requestor) do
      nil ->
        {:error, {:no_user, requestor["handle"], requestor["provider"]}}
      user ->
        {:ok, user}
    end
  end
end
