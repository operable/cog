defmodule Cog.Commands.RelayGroup.Member.Add do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-member-add"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Adds relays to relay groups"

  @arguments "<group-name> <relay-name> [<relay-name> ...]"

  @output_description "Returns the serialized relay group with the new relay included"

  @output_example """
  [
    {
      "relays": [
        {
          "status": "enabled",
          "name": "default",
          "id": "9e173ffd-b247-4833-80d4-a87c4175732d",
          "created_at": "2016-12-13T14:33:48"
        }
      ],
      "name": "production",
      "id": "ee3d7b91-9c66-487d-b250-8df47e7f7a32",
      "created_at": "2016-12-14T00:11:14",
      "bundles": []
    }
  ]
  """

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-member-add must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, min: 2) do
      {:ok, [group_name | relay_names]} ->
        with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
             {:ok, relays} <- RelayGroup.Helpers.get_relays(relay_names),
             :ok <- verify_relays(relays, relay_names) do
               add(relay_group, relays)
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

  defp add(relay_group, relays) do
    member_spec = %{"relays" => %{"add" => Enum.map(relays, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        {:ok, "relay-group-update-success", RelayGroup.json(relay_group)}
      error ->
        {:error, error}
    end
  end

  defp verify_relays(relays, relay_names) do
    case RelayGroup.Helpers.verify_list(relays, relay_names, :name) do
      :ok -> :ok
      {:error, {:values_not_found, missing}} ->
        {:error, {:relays_not_found, missing}}
    end
  end
end
