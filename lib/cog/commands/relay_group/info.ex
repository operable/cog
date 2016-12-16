defmodule Cog.Commands.RelayGroup.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-info"

  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Get info on one or more relay groups"

  @arguments "<group-name> [<group-name> ...]"

  @output_description "Returns the serialized relay group"

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-info must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    relay_groups = RelayGroups.all_by_name(req.args)
    |> Enum.map(&RelayGroup.json/1)

    case relay_groups do
      [] ->
        {:reply, req.reply_to, "No relay groups configured with name in '#{Enum.join(req.args, ", ")}'", state}
      relay_groups ->
        {:reply, req.reply_to, "relay-group-info", relay_groups, state}
    end
  end
end
