defmodule Cog.Commands.RelayGroup.Rename do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-rename"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Renames relay groups"

  @arguments "<old_relay_name> <new_relay_name>"

  @output_description "Returns the serialized relay group with the new name including an old_name attribute"

  @output_example """
  [
    {
      "relay_group": {
        "relays": [
          {
            "status": "enabled",
            "name": "production",
            "id": "9e173ffd-b247-4833-80d4-a87c4175732d",
            "created_at": "2016-12-13T14:33:48"
          }
        ],
        "name": "staging",
        "id": "ee3d7b91-9c66-487d-b250-8df47e7f7a32",
        "created_at": "2016-12-14T00:11:14",
        "bundles": []
      },
      "old_name": "production"
    }
  ]
  """

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-rename must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 2) do
      {:ok, [old_name, new_name]} ->
        case RelayGroups.by_name(old_name) do
          {:ok, relay_group} ->
            rename(relay_group, new_name)
          {:error, :not_found} ->
            {:error, {:relay_group_not_found, old_name}}
        end
      error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  defp rename(relay_group, new_name) do
    case RelayGroups.update(relay_group, %{name: new_name}) do
      {:ok, updated_relay_group} ->
        json = %{old_name: relay_group.name,
                 relay_group: RelayGroup.json(updated_relay_group)}
        {:ok, "relay-group-rename", json}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

end
