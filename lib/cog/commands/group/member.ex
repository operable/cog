defmodule Cog.Commands.Group.Member do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group.Member

  Helpers.usage """
  Manage user group membership.

  USAGE
    group member [FLAGS] <SUBCOMMAND>

  SUBCOMMANDS
    add      Add users to user groups
    remove   Remove users from user groups

  FLAGS
    -h, --help    Display this usage info
  """

  @spec manage_members(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def manage_members(req, []) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      show_usage(error(:invalid_subcommand))
    end
  end
  def manage_members(req, arg_list) do
    {subcommand, args} = Helpers.get_subcommand(arg_list)

    case subcommand do
      "add" ->
        Member.Add.add_user(req, args)
      "remove" ->
        Member.Remove.remove_user(req, args)
      invalid ->
        suggestion = Enum.max_by(["add", "remove"],
                                 &String.jaro_distance(&1, invalid))
        show_usage(error({:unknown_subcommand, invalid, suggestion}))
    end
  end

  defp error(:invalid_subcommand),
    do: "Please specify 'add' or 'remove'."
  defp error({:unknown_subcommand, invalid, suggestion}),
    do: "Unknown subcommand '#{invalid}'. Did you mean '#{suggestion}'?"
end
