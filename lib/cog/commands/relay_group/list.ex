defmodule Cog.Commands.RelayGroup.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-list"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "List all relay groups"

  @output_description "Lists serialized relay groups including their relays"

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

  option "verbose", type: "bool", short: "v"

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-list must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    relay_groups = RelayGroups.all
    |> Enum.map(&RelayGroup.json/1)

    {:reply, req.reply_to, get_template(req.options), relay_groups, state}
  end

  def get_template(options) do
    if Helpers.flag?(options, "verbose") do
      "relay-group-list-verbose"
    else
      "relay-group-list"
    end
  end
end
