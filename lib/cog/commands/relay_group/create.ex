defmodule Cog.Commands.RelayGroup.Create do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-group-create"

  alias Cog.Commands.Helpers
  alias Cog.Repository.RelayGroups
  alias Cog.Commands.RelayGroup

  @description "Creates relay groups"

  @arguments "<group-name>"

  @output_description "Returns the newly created serialized relay group"

  @output_example """
  [
    {
      "relays": [],
      "name": "staging",
      "id": "ee3d7b91-9c66-487d-b250-8df47e7f7a32",
      "created_at": "2016-12-14T00:11:14",
      "bundles": []
    }
  ]
  """

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group-create must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 1) do
      {:ok, [name]} ->
        case RelayGroups.new(%{name: name}) do
          {:ok, relay_group} ->
            {:ok, "relay-group-create", RelayGroup.json(relay_group)}
          {:error, changeset} ->
            {:error, {:db_errors, changeset.errors}}
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
end
