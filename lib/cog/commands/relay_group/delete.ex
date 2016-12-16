defmodule Cog.Commands.RelayGroup.Delete do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-delete"

  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Deletes relay groups"

  @arguments "<group_name>"

  @output_description "Returns the seralized relay group that was deleted"

  @output_example """
  [
    {
      "relays": [
        {
          "status": "enabled",
          "name": "production",
          "id": "9e173ffd-b247-4833-80d4-a87c4175732d",
          "created_at": "2016-12-13T14:33:48"
        }
      ],
      "name": "default",
      "id": "ee3d7b91-9c66-487d-b250-8df47e7f7a32",
      "created_at": "2016-12-14T00:11:14",
      "bundles": []
    }
  ]
  """

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-delete must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 1) do
      {:ok, [group_name]} ->
        case RelayGroups.by_name(group_name) do
          {:ok, relay_group} ->
            delete(relay_group)
          {:error, :not_found} ->
            {:error, {:relay_group_not_found, group_name}}
        end
      error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, RelayGroup.error(err), state}
    end
  end

  defp delete(relay_group) do
    case RelayGroups.delete(relay_group) do
      {:ok, _deleted} ->
        {:ok, "relay-group-delete", RelayGroup.json(relay_group)}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

end
