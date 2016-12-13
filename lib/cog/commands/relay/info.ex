defmodule Cog.Commands.Relay.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-info"

  alias Cog.Commands.Relay
  alias Cog.Commands.Relay.ViewHelpers
  alias Cog.Repository.Relays

  @description "Get detailed information about a relay"

  @arguments "<name>"

  @examples """
  View info for relay:

    relay info foo
  """

  @output_description "Returns the serialized relay including relay groups"

  @output_example """
  [
    {
      "status": "enabled",
      "relay_groups": [],
      "name": "default",
      "id": "9e173ffd-b247-4833-80d4-a87c4175732d",
      "created_at": "2016-12-13T14:33:48",
      "_show_groups": true
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-info must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  option "group", type: "bool", short: "g"
  option "verbose", type: "bool", short: "v"

  def handle_message(req = %{args: [name]}, state) when is_binary(name) do
    result = case Relays.by_name(name) do
      {:ok, relay} ->
        {:ok, "relay-info", ViewHelpers.render(relay, %{"group" => true})}
      {:error, :not_found} ->
        {:error, {:resource_not_found, "relay", name}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Relay.error(err), state}
    end
  end
  def handle_message(req = %{args: [_invalid_permission]}, state),
    do: {:error, req.reply_to, Relay.error(:wrong_type), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Relay.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Relay.error({:too_many_args, 1}), state}

end
