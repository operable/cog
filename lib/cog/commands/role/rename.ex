defmodule Cog.Commands.Role.Rename do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Roles
  alias Cog.Models.Role

  Helpers.usage """
  Rename a role

  USAGE
    role rename [FLAGS] <name> <new-name>

  ARGS
    name      The role to rename
    new-name  The name you want to change to

  FLAGS
    -h, --help    Display this usage info

  EXAMPLES

    role rename aws-admin cloud-commander
  """

  def rename(%{options: %{"help" => true}}, _args),
    do: show_usage
  def rename(_req, [old, new]) when is_binary(old) and is_binary(new) do
    case Roles.by_name(old) do
      %Role{}=role ->
        case Roles.rename(role, new) do
          {:ok, role} ->
            rendered = Cog.V1.RoleView.render("show.json", %{role: role})
            {:ok, "role-rename", Map.put(rendered[:role], :old_name, old)}
          {:error, _}=error ->
            error
        end
      nil ->
        {:error, {:resource_not_found, "role", old}}
    end
  end
  def rename(_, [_,_]),
    do: {:error, :wrong_type}
  def rename(_, args) do
    error = if length(args) > 2, do: :too_many_args, else: :not_enough_args
    {:error, {error, 2}}
  end

end
