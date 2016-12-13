defmodule Cog.Commands.Relay.Update do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-update"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Relay
  alias Cog.Commands.Relay.ViewHelpers
  alias Cog.Repository.Relays

  @description "Updates relay name and/or description"

  @arguments "<relay-name>"

  @output_description "Returns the serialized relay with updated attributes"

  @output_example """
  [
    {
      "status": "enabled",
      "name": "production",
      "id": "9e173ffd-b247-4833-80d4-a87c4175732d",
      "created_at": "2016-12-13T14:33:48"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-update must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  option "name", type: "string"
  option "description", type: "string"

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, 1) do
      {:ok, [relay_name]} ->
        case Relays.by_name(relay_name) do
          {:ok, relay} ->
            do_update(req, relay)
          {:error, :not_found} ->
            {:error, {:relay_not_found, relay_name}}
        end
      error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Relay.error(err), state}
    end
  end

  defp do_update(req, relay) do
    params = Map.take(req.options, ["name", "description"])
    case Relays.update(relay.id, params) do
      {:ok, updated_relay} ->
        {:ok, "relay-update", ViewHelpers.render(updated_relay)}
      {:error, changeset} ->
        {:error, {:db_errors, changeset.errors}}
    end
  end

end
