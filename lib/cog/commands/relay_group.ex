defmodule Cog.Commands.RelayGroup do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, name: "relay-group"
  alias Cog.Commands.RelayGroup
  alias Cog.Commands.Helpers

  @description "Manage relay groups"

  @moduledoc """
  #{@description}

  USAGE
    relay-group <SUBCOMMAND>

  FLAGS
    -h, --help      Display this usage info

  SUBCOMMANDS
    info      Get info about one or more relay groups
    create    Creates a relay group
    rename    Renames a relay group
    delete    Deletes a relay group
    member    Managers relay and bundle assignments
  """

  permission "manage_relays"

  rule "when command is #{Cog.embedded_bundle}:relay-group must have #{Cog.embedded_bundle}:manage_relays"

  # general options
  option "help", type: "bool", short: "h"

  # list options
  option "verbose", type: "bool", short: "v"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "info" ->
        RelayGroup.Info.relay_group_info(req, args)
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
          show_usage(error(:required_subcommand))
        end
      invalid ->
        show_usage(error({:unknown_subcommand, invalid}))
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

  defp error(:required_subcommand),
    do: "You are required to specify a subcommand. Please specify one of, 'info', 'create', 'rename', 'delete' or 'member'"
  defp error({:unknown_subcommand, subcommand}),
    do: "Unknown subcommand '#{subcommand}'. Please specify one of, 'info', 'create', 'rename', 'delete' or 'member'"

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduledoc, error: error}}
  end
end
