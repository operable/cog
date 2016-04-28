defmodule Cog.Commands.Permissions do
  @moduledoc """
  Manipulate authorization permissions.

  * Create permissions in the `site` namespace
  * Delete permissions in the `site` namespace
  * List all permissions in the system
  * Grant and revoke permissions from roles.

  Format:

      --list
      --create --permission=site:<name>
      --delete --permission=site:<name>
      --grant --permission=<namespace>:<permission> --role=<name>"
      --revoke --permission=<namespace>:<permission> --role=<name>"

  Examples:

  > !#{Cog.embedded_bundle}:permissions --list
  > !#{Cog.embedded_bundle}:permissions --create --permission=site:admin
  > !#{Cog.embedded_bundle}:permissions --delete --permission=site:admin
  > !#{Cog.embedded_bundle}:permissions --grant --role=dev --permission=site:write
  > !#{Cog.embedded_bundle}:permissions --revoke --role=dev --permission=giphy:giphy

  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  option "create", type: "bool"
  option "delete", type: "bool"
  option "list", type: "bool"
  option "grant", type: "bool"
  option "revoke", type: "bool"
  option "role", type: "string"
  option "permission", type: "string"

  permission "manage_permissions"
  permission "manage_roles"

  rule "when command is #{Cog.embedded_bundle}:permissions with option[create] == true must have #{Cog.embedded_bundle}:manage_permissions"
  rule "when command is #{Cog.embedded_bundle}:permissions with option[delete] == true must have #{Cog.embedded_bundle}:manage_permissions"
  rule "when command is #{Cog.embedded_bundle}:permissions with option[list] == true must have #{Cog.embedded_bundle}:manage_permissions"
  rule "when command is #{Cog.embedded_bundle}:permissions with option[grant] == true must have #{Cog.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.embedded_bundle}:permissions with option[revoke] == true must have #{Cog.embedded_bundle}:manage_roles"

  alias Cog.Repo
  use Cog.Models

  defstruct req: nil, action: nil, permittable: nil, permission: nil, errors: []

  def handle_message(req, state) do
    result = Repo.transaction(fn() ->
      case validate(req) do
        %__MODULE__{errors: []}=result ->
          case result.action do
            :list ->
              names = Cog.Queries.Permission.names
              |> Repo.all
              |> Enum.map(&Enum.join(&1, ":"))
              {:list, names}
            :create ->
              {ns,name} = Permission.split_name(result.permission)
              namespace = Repo.get_by(Namespace, name: ns)
              permission = Permission.build_new(namespace, %{name: name})
              case Repo.insert(permission) do
                {:ok, _} ->
                  {:create, result.permission}
                {:error, changeset} ->
                  Repo.rollback(changeset.errors)
              end
            :delete ->
              permission = Cog.Queries.Permission.from_full_name(result.permission)|> Repo.one!
              Repo.delete!(permission)
              {:delete, result.permission}
            :grant ->
              Permittable.grant_to(result.permittable, result.permission)
              Cog.Command.PermissionsCache.reset_cache
              {:grant, result.permittable, req.options["permission"]}
            :revoke ->
              Permittable.revoke_from(result.permittable, result.permission)
              Cog.Command.PermissionsCache.reset_cache
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
      %{"create" => true} -> %{input | action: :create}
      %{"delete" => true} -> %{input | action: :delete}
      %{"list" => true} -> %{input | action: :list}
      %{"grant" => true} -> %{input | action: :grant}
      %{"revoke" => true} -> %{input | action: :revoke}
      _ -> %{input | errors: errors ++ [:missing_action]}
    end
  end

  defp validate_permittable(%__MODULE__{action: action}=input) when action in [:create, :delete, :list],
    do: input # nothing to validate in this case
  defp validate_permittable(%__MODULE__{req: req, errors: errors}=input) do
    case req.options do
      %{"role" => name} ->
        case Repo.get_by(Role, name: name) do
          %Role{}=role -> %{input | permittable: role}
          nil -> %{input | errors: errors ++ [{:unrecognized_role, name}]}
        end
      _ ->
        %{input | errors: errors ++ [:missing_permittable]}
    end
  end

  defp validate_permission(%__MODULE__{action: :list}=input),
    do: input # nothing to validate here
  defp validate_permission(%__MODULE__{req: req, errors: errors, action: action}=input) when action in [:create, :delete] do
    case req.options do
      %{"permission" => name} when is_binary(name) ->
        case String.split(name, ":") do
          ["site", _permission] ->
            case Cog.Queries.Permission.from_full_name(name) |> Repo.one do
              nil ->
                case action do
                  :create ->
                    %{input | permission: name}
                  :delete ->
                    %{input | errors: errors ++ [{:unrecognized_permission, name}]}
                end
              %Permission{} ->
                case action do
                  :create ->
                    %{input | errors: errors ++ [{:permission_exists, name}]}
                  :delete ->
                    %{input | permission: name}
                end
            end
          _ ->
            %{input | errors: errors ++ [:invalid_creation_permission]}
        end
      %{"permission" => wrong_type} ->
        %{input | errors: errors ++ [{:wrong_type, {:option, :permission}, :string, wrong_type}]}
      _ ->
        %{input | errors: errors ++ [:missing_permission]}
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

  defp translate_success({:list, names}) do
    strings = names |> Enum.map(&("* #{&1}\n"))
    """
    The following permissions exist:

    #{strings}
    """
  end
  defp translate_success({:create, permission_full_name}),
    do: "Created permission `#{permission_full_name}`"
  defp translate_success({:delete, permission_full_name}),
    do: "Deleted permission `#{permission_full_name}`"
  defp translate_success({:grant, permittable, permission_full_name}),
    do: "Granted permission `#{permission_full_name}` to role `#{permittable.name}`"
  defp translate_success({:revoke, permittable, permission_full_name}),
    do: "Revoked permission `#{permission_full_name}` from role `#{permittable.name}`"

  defp translate_error(:missing_action),
    do: "Must specify one of the following actions: `--grant` or `--revoke`"
  defp translate_error({:unrecognized_role, name}),
    do: "Could not find role `#{name}`"
  defp translate_error(:missing_permittable),
    do: "Must specify a role to act upon with `--role`"
  defp translate_error({:unrecognized_permission, name}),
    do: "Could not find permission `#{name}`"
  defp translate_error(:missing_permission),
    do: "Must specify a permission to operate on using `--permission`"
  defp translate_error({:permission_exists, name}),
    do: "The permission `#{name}` already exists"
  defp translate_error(:invalid_creation_permission),
    do: "Only permissions in the `site` namespace can be created or deleted; please specify permission as `site:<NAME>`"
  defp translate_error({:wrong_type, {opt_or_arg, opt_or_arg_name}, desired_type, given_value}),
    do: "The #{opt_or_arg} `#{opt_or_arg_name}` must be a #{desired_type}; you gave `#{inspect given_value}`"
  defp translate_error(other),
    do: "Error: `#{inspect other}`"
end
