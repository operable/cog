defmodule Cog.Commands.RelayGroup.Member.Assign do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-member-assign"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Assigns bundles to relay groups"

  @arguments "<group-name> <bundle-name> [<bundle-name> ...]"

  @output_description "Returns the serialized relay group with the assigned bundle included"

  @output_example """
  [
    {
      "relays": [],
      "name": "production",
      "id": "ee3d7b91-9c66-487d-b250-8df47e7f7a32",
      "created_at": "2016-12-14T00:11:14",
      "bundles": [
        {
          "name": "cfn"
        }
      ]
    }
  ]
  """

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-member-assign must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, min: 2) do
      {:ok, [group_name | bundle_names]} ->
        with {:ok, relay_group} <- RelayGroup.Helpers.get_relay_group(group_name),
             {:ok, bundles} <- RelayGroup.Helpers.get_bundles(bundle_names),
             :ok <- verify_bundles(bundles, bundle_names) do
               assign(relay_group, bundles)
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

  defp assign(relay_group, bundles) do
    member_spec = %{"bundles" => %{"add" => Enum.map(bundles, &(&1.id))}}
    case RelayGroups.manage_association(relay_group, member_spec) do
      {:ok, relay_group} ->
        data = relay_group
        |> RelayGroup.json
        |> Map.put("bundles_assigned", Enum.map(bundles, &(&1.name)))
        {:ok, "relay-group-member-assign", data}
      error ->
        {:error, error}
    end
  end

  defp verify_bundles(bundles, bundle_names) do
    case RelayGroup.Helpers.verify_list(bundles, bundle_names, :name) do
      :ok -> :ok
      {:error, {:values_not_found, missing}} ->
        {:error, {:bundles_not_found, missing}}
    end
  end
end
