defmodule Cog.Commands.Relay.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "relay-list"

  alias Cog.Commands.Relay
  alias Cog.Commands.Relay.ViewHelpers
  alias Cog.Repository.Relays

  @description "Lists relays"

  @output_description "Returns a list of serailized relays"

  @output_example """
  [
    {
      "status": "enabled",
      "name": "default",
      "id": "9e173ffd-b247-4833-80d4-a87c4175732d",
      "created_at": "2016-12-13T14:33:48"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-list must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  option "group", type: "bool", short: "g"
  option "verbose", type: "bool", short: "v"

  def handle_message(req, state) do
    result = case Relays.all do
      [] ->
        {:ok, "No relays configured"}
      relays ->
        template = ViewHelpers.template("relay-list", req.options)
        data     = ViewHelpers.render(relays, req.options)
        {:ok, template, data}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, Relay.error(err), state}
    end
  end

end
