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
    > No matching commands or aliases
  """

  def handle_message(req, state) do
    user = Helpers.get_user(req.requestor)
    case Helpers.get_args(req.args, count: 1) do
      {:ok, [arg]} ->
        {:reply, req.reply_to, "which", which(user, arg), state}
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
            %{}
          %Command{} ->
            bundle = Queries.Command.bundle_for(arg)
            |> Repo.one!
            %{type: "command", scope: bundle, name: arg}
        end
      %UserCommandAlias{pipeline: pipeline} ->
        %{type: "alias", scope: "user", name: arg, pipeline: pipeline}
      %SiteCommandAlias{pipeline: pipeline} ->
        %{type: "alias", scope: "site", name: arg, pipeline: pipeline}
    end
  end
end
