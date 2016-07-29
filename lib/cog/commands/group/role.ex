defmodule Cog.Commands.Group.Role do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group.Role

  Helpers.usage """
  Manage user group roles.

  USAGE
    group role [FLAGS] <SUBCOMMAND>

  SUBCOMMANDS
    add      Add roles to user group
    remove   Remove roles from user group

  FLAGS
    -h, --help    Display this usage info
  """

  @spec manage_roles(%Cog.Messages.Command{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def manage_roles(req, []) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      show_usage(error(:invalid_subcommand))
    end
  end
  def manage_roles(req, arg_list) do
    {subcommand, args} = Helpers.get_subcommand(arg_list)

    case subcommand do
      "add" ->
        Role.Add.add_role(req, args)
      "remove" ->
        Role.Remove.remove_role(req, args)
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
