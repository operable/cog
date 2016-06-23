defmodule Cog.Commands.Permission.Info do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Permissions
  alias Cog.Models.Permission

  Helpers.usage """
  Get detailed information about a permission.

  USAGE
    permission info [FLAGS] <name>

  ARGS
    name    The permission to get info about

  FLAGS
    -h, --help    Display this usage info

  EXAMPLES

    permission info site:foo
  """

  def info(%{options: %{"help" => true}}, _args),
    do: show_usage
  def info(_req, [name]) when is_binary(name) do
    case Permissions.by_name(name) do
      %Permission{}=permission ->
        rendered = Cog.V1.PermissionView.render("show.json", %{permission: permission})
        {:ok, "permission-info", rendered[:permission]}
      nil ->
        {:error, {:resource_not_found, "permission", name}}
    end
  end
  def info(_, [_]),
    do: {:error, :wrong_type}
  def info(_, []),
    do: {:error, {:not_enough_args, 1}}
  def info(_, _),
    do: {:error, {:too_many_args, 1}}

end
