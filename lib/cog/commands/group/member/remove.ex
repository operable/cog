defmodule Cog.Commands.Group.Member.Remove do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "group-member-remove"

  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group
  alias Cog.Repository.Groups
  alias Cog.Repository.Users

  @description "Removes users from user groups"

  @arguments "<group-name> <user-name ...>"

  @output_description "Returns the serialized group without the removed member"

  @output_example """
  [
    {
      "roles": [],
      "name": "engineering",
      "members": [],
      "id": "0640f71f-3c1b-4d47-8b8b-c8765b115872"
    }
  ]
  """

  rule ~s(when command is #{Cog.Util.Misc.embedded_bundle}:group-member-remove must have #{Cog.Util.Misc.embedded_bundle}:manage_users)

  def handle_message(req, state) do
    result = case Helpers.get_args(req.args, min: 2) do
      {:ok, [group_name | usernames]} ->
        case remove(group_name, usernames) do
          {:ok, group} ->
            {:ok, "user-group-update-success", group}
          error ->
            error
        end
      error -> 
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Group.error(err), state}
    end
  end

  defp remove(group_name, usernames) do
    case Groups.by_name(group_name) do
      {:ok, group} ->
        case Users.all_with_username(usernames) do
          {:ok, users} ->
            Groups.manage_membership(group, %{"members" => %{"remove" => users}})
          {:some, _users, not_found} ->
            {:error, {:resource_not_found, "user", Enum.join(not_found, ", ")}}
          {:error, :not_found} ->
            {:error, {:resource_not_found, "user", Enum.join(usernames, ", ")}}
        end
      {:error, :not_found} ->
        {:error, {:resource_not_found, "user group", group_name}}
    end
  end
end
