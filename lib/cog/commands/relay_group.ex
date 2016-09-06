defmodule Cog.Commands.RelayGroup do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle, name: "relay-group"
  alias Cog.Commands.RelayGroup
  alias Cog.Commands.Helpers

  @description "Manage relay groups"

  @subcommands %{
    "list" => "List relay groups (default)",
    "info <relay-group>" => "Get info about one or more relay groups",
    "create <relay-group>" => "Creates a relay group",
    "delete <relay-group>" => "Deletes a relay group",
    "member <subcommand>" => "Managers relay and bundle assignments",
    "rename <relay-group> <new-relay-group>" => "Renames a relay group"
  }

  permission "manage_relays"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:relay-group must have #{Cog.Util.Misc.embedded_bundle}:manage_relays"

  # general options
  option "help", type: "bool", short: "h"

  # list options
  option "verbose", type: "bool", short: "v"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "info" ->
        RelayGroup.Info.relay_group_info(req, args)
      "list" ->
        RelayGroup.List.list(req, args)
      "create" ->
        RelayGroup.Create.create_relay_group(req, args)
      "rename" ->
        RelayGroup.Rename.rename_relay_group(req, args)
      "delete" ->
        RelayGroup.Delete.delete_relay_group(req, args)
      "member" ->
        RelayGroup.Member.member(req, args)
      nil ->
        if Helpers.flag?(req.options, "help") do
          show_usage
        else
          RelayGroup.List.list(req, args)
        end
      other ->
        {:error, {:unknown_subcommand, other}}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  @doc """
  Returns a map representing a relay group from a relay group model.
  """
  @spec json(%Cog.Models.RelayGroup{}) :: Map.t
  def json(relay_group) do
    %{"name" => relay_group.name,
      "id" => relay_group.id,
      "created_at" => relay_group.inserted_at,
      "relays" => Enum.map(relay_group.relays, &Cog.Commands.Relay.ViewHelpers.render/1),
      "bundles" => Enum.map(relay_group.bundles, &bundle_json/1)}
  end

  defp bundle_json(bundle) do
    %{"name" => bundle.name}#,
#      "version" => bundle.version,
   #   "status" => bundle_status(bundle)}
  end

  # defp bundle_status(%{enabled: true}),
  #   do: :enabled
  # defp bundle_status(%{enabled: false}),
  #   do: :disabled

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end
