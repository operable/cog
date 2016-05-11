defmodule Cog.Commands.RelayGroup.Member do
  alias Cog.Commands.Helpers
  alias Cog.Commands.RelayGroup.Member

  @moduldoc """
  Manages relay and bundle assignments to relay groups.

  USAGE
    relay-group member <relay group name> <SUBCOMMAND>

  ARGS
    group_name    The relay group to operate on

  FLAGS
    -h, --help      Display this usage info

  SUBCOMMANDS
    add       Adds relays to relay groups
    remove    Removes relays from relay groups
    assign    Assigns bundles to relay groups
    unassign  Un-assigns bundles from relay groups
  """

  def member(req, []) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      show_usage(error(:invalid_subcommand))
    end
  end
  def member(req, arg_list) do
    {group_name, subcommand, args} = Helpers.get_resource_subcommand(arg_list)

    case subcommand do
      "add" ->
        Member.Add.add_relays(group_name, req, args)
      "remove" ->
        Member.Remove.remove_relays(group_name, req, args)
      "assign" ->
        Member.Assign.assign_bundles(group_name, req, args)
      "unassign" ->
        Member.Unassign.unassign_bundles(group_name, req, args)
      invalid ->
        show_usage(error(:invalid_subcommand, invalid))
    end
  end

  defp error(:invalid_subcommand) do
    "Please specify 'add', 'remove', 'assign' or 'unassign'."
  end
  defp error(:invalid_subcommand, invalid) do
    "Invalid subcommand '#{invalid}' for 'member'. Please specify 'add', 'remove', 'assign' or 'unassign'."
  end

  defp show_usage(error \\ nil) do
    {:ok, "usage", %{usage: @moduldoc, error: error}}
  end
end
