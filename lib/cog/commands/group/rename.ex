defmodule Cog.Commands.Group.Rename do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Groups

  Helpers.usage """
  Rename a group

  USAGE
    group rename [FLAGS] <name> <new-name>

  ARGS
    name      The group to rename
    new-name  The name you want to change to

  FLAGS
    -h, --help    Display this usage info

  EXAMPLES

    group rename dev engineering
  """

  def rename(%{options: %{"help" => true}}, _args),
    do: show_usage
  def rename(_req, [old, new]) when is_binary(old) and is_binary(new) do
    case Groups.by_name(old) do
      {:ok, group} ->
        case Groups.update(group, %{name: new}) do
          {:ok, group} ->
            rendered = Cog.V1.GroupView.render("show.json", %{group: group})
            {:ok, "group-rename", Map.put(rendered[:group], :old_name, old)}
          {:error, _}=error ->
            error
        end
      {:error, :not_found} ->
        {:error, {:resource_not_found, "group", old}}
    end
  end
  def rename(_, [_,_]),
    do: {:error, :wrong_type}
  def rename(_, args) do
    error = if length(args) > 2, do: :too_many_args, else: :not_enough_args
    {:error, {error, 2}}
  end

end
