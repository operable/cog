defmodule Cog.Commands.Role do
  @moduledoc """
  This command allows the user to manage roles.

  Usage:
      role --create <rolename>
      role --drop <rolename>
      role --grant --group=<groupname> <rolename>
      role --revoke --group=<groupname> <rolename>
      role --list
  Examples:
  > @bot operable:role --create deployment
  > @bot operable:role --grant --group=ops deployment
  > @bot operable:role --revoke --group=ops deployment
  > @bot operable:role --drop deployment
  > @bot operable:role --list
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  option "create", type: "bool"
  option "drop", type: "bool"
  option "grant", type: "bool"
  option "revoke", type: "bool"
  option "list", type: "bool"

  option "group", type: "string"

  permission "manage_roles"
  permission "manage_groups"

  rule "when command is #{Cog.embedded_bundle}:role with option[create] == true must have #{Cog.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.embedded_bundle}:role with option[drop] == true must have #{Cog.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.embedded_bundle}:role with option[list] == true must have #{Cog.embedded_bundle}:manage_roles"
  rule "when command is #{Cog.embedded_bundle}:role with option[grant] == true must have #{Cog.embedded_bundle}:manage_groups"
  rule "when command is #{Cog.embedded_bundle}:role with option[revoke] == true must have #{Cog.embedded_bundle}:manage_groups"

  alias Cog.Repo
  alias Cog.MessageTranslations
  use Cog.Models

  def handle_message(req, state) do
    result = case req.options do
                 %{"create" => true} -> create_role(req.args)
                 %{"drop" => true} -> drop_role(req.args)
                 %{"grant" => true} -> modify_role(req)
                 %{"revoke" => true} -> modify_role(req)
                 %{"list" => true} -> list_all_roles
                 _ -> {:error, "I am not sure what action you want me to take using `role`"}
    end

    case result do
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, message} ->
        {:error, req.reply_to, message, state}
    end
  end

  defp create_role([]),
    do: MessageTranslations.translate_error("Missing name", {:fail_creation, ""})
  defp create_role([name | _]) do
    case Repo.get_by(Role, name: name) do
      nil ->
        case Role.changeset(%Role{}, %{name: name}) |> Repo.insert do
          {:ok, role} -> MessageTranslations.translate_success(%{action: :create, entity: role})
          {:error, errmsg} -> MessageTranslations.translate_error(errmsg, {:fail_creation, name})
        end
      %Role{} ->
        MessageTranslations.translate_error("role", {:already_exists, name})
    end
  end

  defp drop_role([name | _]) do
    case Repo.get_by(Role, name: name) do
      %Role{}=role ->
        case existing_assignments?(name) do
          false ->
            Repo.delete!(role)
            MessageTranslations.translate_success(%{action: :drop, entity: role})
          roles ->
            {:error, message} = MessageTranslations.translate_error("role", {:fail_deletion, name})
            {:error, message <> " There are assignments to this role: \n#{roles}"}
        end
      nil -> MessageTranslations.translate_error("role", {:does_not_exists, name})
    end
  end

  defp existing_assignments?(rolename) do
    case Cog.Queries.Permission.from_group_roles(rolename)|> Repo.all do
      [] ->
        false
      assigned_roles ->
        Enum.map_join(assigned_roles, "\n",
          fn(%{group: group}) -> "* group: #{group.name}" end)
    end
  end

  defp modify_role(req) do
    enrollee = validate(req)
    case enrollee.errors do
      [] ->
        perform_action(enrollee.action, enrollee)
        |> return_results(enrollee)
      _ -> return_results(:error, enrollee)
    end
  end

  defp list_all_roles do
    result = Repo.all(Role)
    case result do
      [] -> {:ok, "Currently, there are no roles in the system."}
      _ -> {:ok, format_list(result, "")}
    end
  end

  defp perform_action(:grant, enrollee) do
    Permittable.grant_to(enrollee.entity, enrollee.classification)
  end
  defp perform_action(:revoke, enrollee) do
    Permittable.revoke_from(enrollee.entity, enrollee.classification)
  end

  defp return_results(:ok, %{action: :grant} = enrollee),
    do: MessageTranslations.translate_success(enrollee)
  defp return_results(:ok, %{action: :revoke} = enrollee),
    do: MessageTranslations.translate_success(enrollee)
  defp return_results(_, enrollee) do
    [error | _] = enrollee.errors
    MessageTranslations.translate_error("role", error)
  end

  defp validate(req) do
    %MessageTranslations{req: req}
    |> validate_action
    |> validate_enrollee
    |> validate_role
  end

  defp validate_action(%{req: req, errors: errors}=input) do
    case req.options do
      %{"grant" => true} -> %{input | action: :grant}
      %{"revoke" => true} -> %{input | action: :revoke}
      _ -> %{input | errors: [:missing_action | errors]}
    end
  end

  defp validate_enrollee(%{req: req, errors: errors}=input) do
    case req.options do
      %{"group" => name} ->
        case Repo.get_by(Group, name: name) do
          %Group{}=group -> %{input | entity: group}
          nil -> %{input | errors: [{:unrecognized_group, name} | errors]}
        end
      _ ->
        %{input | errors: [:missing_target | errors]}
    end
  end

  defp format_list([], acc) do
    "The following are the available roles: \n#{acc}"
  end
  defp format_list([%{name: name} | remaining], acc) do
    format_list(remaining, "* #{name}\n" <> acc)
  end

  defp validate_role(%{req: req, errors: errors}=input) do
    case req.args do
      [name | _] ->
        case Repo.get_by(Role, name: name) do
          %Role{}=role -> %{input | classification: role}
          nil -> %{input | errors: [{:unrecognized_role, name} | errors]}
        end
      [] -> %{input | errors: [:missing_role | errors]}
    end
  end

end
