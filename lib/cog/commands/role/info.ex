defmodule Cog.Commands.Role.Info do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Roles
  alias Cog.Models.Role

  Helpers.usage """
  Get detailed information about a role.

  USAGE
    role info [FLAGS] <name>

  ARGS
    name    The role to get info about

  FLAGS
    -h, --help    Display this usage info

  EXAMPLES

    role info foo
  """

  def info(%{options: %{"help" => true}}, _args),
    do: show_usage
  def info(_req, [name]) when is_binary(name) do
    case Roles.by_name(name) do
      %Role{}=role ->
        rendered = Cog.V1.RoleView.render("show.json", %{role: role})
        {:ok, "role-info", rendered[:role]}
      nil ->
        {:error, {:resource_not_found, "role", name}}
    end
  end
  def info(_, [_]),
    do: {:error, :wrong_type}
  def info(_, []),
    do: {:error, {:not_enough_args, 1}}
  def info(_, _),
    do: {:error, {:too_many_args, 1}}

end
