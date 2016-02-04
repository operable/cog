defmodule Cog.Commands.Permissions do
  @moduledoc """
  Grant and revoke permissions on users, roles, and groups.

  Format:

      --grant --permission=<namespace>:<permission> --[user|group|role]=<name>"
      --revoke --permission=<namespace>:<permission> --[user|group|role]=<name>"

  Examples:

  > @bot operable:permissions --grant --user=bob --permission=operable:manage_users
  > @bot operable:permissions --grant --role=dev --permission=site:write
  > @bot operable:permissions --revoke --group=engineering --permission=operable:giphy

  """
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle

  option "grant", type: "bool"
  option "revoke", type: "bool"
  option "user", type: "string"
  option "group", type: "string"
  option "role", type: "string"
  option "permission", type: "string"

  permission "manage_users"
  permission "manage_roles"
  permission "manage_groups"

  rule "when command is #{Cog.embedded_bundle}:permissions with option[user] == /.*/ must have #{Cog.embedded_bundle}:manage_users"
  rule "when command is #{Cog.embedded_bundle}:permissions with option[role] == /.*/ must have #{Cog.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.embedded_bundle}:permissions with option[group] == /.*/ must have #{Cog.embedded_bundle}:manage_groups"

  alias Cog.Repo
  use Cog.Models

  defstruct req: nil, action: nil, permittable: nil, permission: nil, errors: []

  def handle_message(req, state) do
    result = Repo.transaction(fn() ->
      case validate(req) do
        %__MODULE__{errors: []}=result ->
          case result.action do
            :grant ->
              Permittable.grant_to(result.permittable, result.permission)
              Cog.Command.UserPermissionsCache.reset_cache
              {:grant, result.permittable, req.options["permission"]}
            :revoke ->
              Permittable.revoke_from(result.permittable, result.permission)
              Cog.Command.UserPermissionsCache.reset_cache
              {:revoke, result.permittable, req.options["permission"]}
          end
        %__MODULE__{errors: errors} ->
          Repo.rollback(errors)
      end
    end)

   case result do
     {:ok, success} ->
       {:reply, req.reply_to, translate_success(success), state}
     {:error, errors} ->
       error_strings = errors
       |> Enum.map(&translate_error/1)
       |> Enum.map(&("* #{&1}\n"))

       # TODO: Really should template this
       response = """

                  #{error_strings}
                  """
       {:error, req.reply_to, response, state}
   end
  end

  defp validate(req) do
    %__MODULE__{req: req}
    |> validate_action
    |> validate_permittable
    |> validate_permission
  end

  defp validate_action(%__MODULE__{req: req, errors: errors}=input) do
    case req.options do
      %{"grant" => true} -> %{input | action: :grant}
      %{"revoke" => true} -> %{input | action: :revoke}
      _ -> %{input | errors: errors ++ [:missing_action]}
    end
  end

  defp validate_permittable(%__MODULE__{req: req, errors: errors}=input) do
    case req.options do
      %{"user" => username} ->
        case Repo.get_by(User, username: username) do
          %User{}=user -> %{input | permittable: user}
          nil -> %{input | errors: errors ++ [{:unrecognized_user, username}]}
        end
      %{"group" => name} ->
        case Repo.get_by(Group, name: name) do
          %Group{}=group -> %{input | permittable: group}
          nil -> %{input | errors: errors ++ [{:unrecognized_group, name}]}
        end
      %{"role" => name} ->
        case Repo.get_by(Role, name: name) do
          %Role{}=role -> %{input | permittable: role}
          nil -> %{input | errors: errors ++ [{:unrecognized_role, name}]}
        end
      _ ->
        %{input | errors: errors ++ [:missing_permittable]}
    end
  end

  defp validate_permission(%__MODULE__{req: req, errors: errors}=input) do
    case req.options do
      %{"permission" => full_name} ->
        permission = full_name
        |> Cog.Queries.Permission.from_full_name
        |> Repo.one

        case permission do
          %Permission{} -> %{input | permission: permission}
          nil -> %{input | errors: errors ++ [{:unrecognized_permission, full_name}]}
        end
      _ ->
        %{input | errors: errors ++ [:missing_permission]}
    end
  end

  # TODO: Really should template these

  defp translate_success({:grant, permittable, permission_full_name}),
    do: "Granted permission `#{permission_full_name}` to #{type(permittable)} `#{name(permittable)}`"
  defp translate_success({:revoke, permittable, permission_full_name}),
    do: "Revoked permission `#{permission_full_name}` from #{type(permittable)} `#{name(permittable)}`"

  defp type(%User{}), do: "user"
  defp type(%Group{}), do: "group"
  defp type(%Role{}), do: "role"

  defp name(%User{username: name}), do: name
  defp name(%Group{name: name}), do: name
  defp name(%Role{name: name}), do: name

  defp translate_error(:missing_action),
    do: "Must specify one of the following actions: `--grant` or `--revoke`"
  defp translate_error({:unrecognized_user, name}),
    do: "Could not find user `#{name}`"
  defp translate_error({:unrecognized_group, name}),
    do: "Could not find group `#{name}`"
  defp translate_error({:unrecognized_role, name}),
    do: "Could not find role `#{name}`"
  defp translate_error(:missing_permittable),
    do: "Must specify a target to act upon with one of: `--user`, `--group`, or `--role`"
  defp translate_error({:unrecognized_permission, name}),
    do: "Could not find permission `#{name}`"
  defp translate_error(:missing_permission),
    do: "Must specify a permission to grant or revoke using `--permission`"

end
