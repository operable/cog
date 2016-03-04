defmodule Cog.Commands.Which do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Models.Command
  alias Cog.Queries
  alias Cog.Repo

  def handle_message(req, state) do
    user = Helpers.get_user(req.requestor)
    case Helpers.get_args(req.args, count: 1) do
      {:ok, [arg]} ->
        {:reply, req.reply_to, "which", which(user, arg), state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

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
      %UserCommandAlias{} ->
        %{type: "alias", scope: "user", name: arg}
      %SiteCommandAlias{} ->
        %{type: "alias", scope: "site", name: arg}
    end
  end
end
