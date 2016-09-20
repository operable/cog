defmodule Cog.Commands.RelayGroup.Member do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.RelayGroup.Member

  Helpers.usage """
  Manages relay and bundle assignments to relay groups.

  USAGE
    relay-group member <SUBCOMMAND>

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
    {subcommand, args} = Helpers.get_subcommand(arg_list)

    case subcommand do
      "add" ->
        Member.Add.add_relays(req, args)
      "remove" ->
        Member.Remove.remove_relays(req, args)
      "assign" ->
        Member.Assign.assign_bundles(req, args)
      "unassign" ->
        Member.Unassign.unassign_bundles(req, args)
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

end
