defmodule Cog.Commands.Group.Rename do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-rename"

  alias Cog.Commands.Group
  alias Cog.Repository.Groups

  @description "Rename a group"

  @arguments "<name> <new-name>"

  @examples """
  Rename the dev group to engineering:

    group rename dev engineering
  """

  @output_description "Returns the serialized group with an extra old_name attribute"

  @output_example """
  [
    {
      "old_name": "ops",
      "name": "engineering",
      "members": {
        "users": [],
        "roles": [],
        "groups": []
      },
      "id": "0640f71f-3c1b-4d47-8b8b-c8765b115872"
    }
  ]
  """

  permission "manage_groups"

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-rename must have #{Cog.Util.Misc.embedded_bundle}:manage_groups)

  def handle_message(req = %{args: [old, new]}, state) when is_binary(old) and is_binary(new) do
    result = case Groups.by_name(old) do
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

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Group.error(err), state}
    end
  end
  def handle_message(req = %{args: [_,_]}, state),
    do: {:error, req.reply_to, Group.error(:wrong_type), state}
  def handle_message(req = %{args: args}, state) when length(args) > 2,
    do: {:error, req.reply_to, Group.error({:too_many_args, 2}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Group.error({:not_enough_args, 2}), state}

end
