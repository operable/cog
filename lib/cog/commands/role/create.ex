defmodule Cog.Commands.Role.Create do
  alias Cog.Repository.Roles
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Create a new role.

  USAGE
    role create [FLAGS] <name>

  FLAGS
    -h, --help  Display this usage info

  ARGS
    name     The name of the role to create.

  EXAMPLE

    role create foo

  """

  def create(%{options: %{"help" => true}}, _args),
    do: show_usage
  def create(_req, [role]) when is_binary(role) do
    case Roles.new(role) do
      {:ok, role} ->
        rendered = Cog.V1.RoleView.render("show.json", %{role: role})
        {:ok, "role-create", rendered[:role]}
      {:error, _}=error ->
        error
    end
  end
  def create(_req, [_]),
    do: {:error, :wrong_type}
  def create(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def create(_req, _),
    do: {:error, {:too_many_args, 1}}

end
