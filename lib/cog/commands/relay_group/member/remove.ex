defmodule Cog.Commands.RelayGroup.Member.Remove do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-member-remove"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Removes relays from relay groups"

  @arguments "<group-name> <relay-name> [<relay-name> ...]"

  @output_description "Returns the serialized relay group with the relay removed"

  @output_example """
  [
    {
      "relays": [],
      "name": "production",
      "id": "ee3d7b91-9c66-487d-b250-8df47e7f7a32",
      "created_at": "2016-12-14T00:11:14",
      "bundles": []
    }
  ]
  """

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-member-remove must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, min: 2) do
      {:ok, [group_name | relay_names]} ->
        with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
             {:ok, relays} <- RelayGroup.Helpers.get_relays(relay_names) do
               remove(relay_group, relays)
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

  defp remove(relay_group, relays) do
    member_spec = %{"relays" => %{"remove" => Enum.map(relays, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        data = relay_group
        |> RelayGroup.json
        |> Map.put("relays_removed", Enum.map(relays, &(&1.name)))
        {:ok, "relay-group-member-remove", data}
      error ->
        {:error, error}
    end
  end
end
