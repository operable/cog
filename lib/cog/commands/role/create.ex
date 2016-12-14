defmodule Cog.Commands.Role.Create do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "role-create"

  alias Cog.Repository.Roles
  alias Cog.Commands.Role

  @description "Create a new role"

  @arguments "<name>"

  @examples """
  Creating a role named ops:

    role create ops
  """

  @output_description "Returns the serialized role that was created"

  @output_example """
  [
    {
      "permissions": [],
      "name": "admin",
      "id": "6eaf55ca-0268-463a-b6bc-3eab4d1c2346"
    }
  ]
  """

  permission "manage_roles"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:role-create must have #{Cog.Util.Misc.embedded_bundle}:manage_roles"

  def handle_message(req = %{args: [role]}, state) when is_binary(role) do
    result = case Roles.new(role) do
      {:ok, role} ->
        rendered = Cog.V1.RoleView.render("show.json", %{role: role})
        {:ok, "role-create", rendered[:role]}
      {:error, _}=error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Role.error(err), state}
    end
  end
  def handle_message(req = %{args: [_]}, state),
    do: {:error, req.reply_to, Role.error(:wrong_type), state}
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Role.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Role.error({:too_many_args, 1}), state}
end
