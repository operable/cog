defmodule Cog.Commands.Group do
  @moduledoc """
  This command allows the user to manage groups. Groups can contain other groups
  or users.

  Usage:
      group --create <groupname>
      group --drop <groupname>
      group --add [--user=<username> | --group=<groupname>] <groupname>
      group --remove [--user=<username> | --group=<groupname>] <groupname>
      group --list
  Examples:
  > @bot operable:group --create ops
  > @bot operable:group --create engineering
  > @bot operable:group --add --user=bob ops
  > @bot operable:group --add --group=ops engineering
  > @bot operable:group --remove --user=bob ops
  > @bot operable:group --drop ops
  > @bot operable:group --list
  """
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle

  option "create", type: "bool"
  option "drop", type: "bool"
  option "add", type: "bool"
  option "remove", type: "bool"
  option "list", type: "bool"

  option "user", type: "string"
  option "group", type: "string"

  permission "manage_groups"
  permission "manage_users"

  rule "when command is #{Cog.embedded_bundle}:group must have #{Cog.embedded_bundle}:manage_groups"

  alias Cog.Repo
  use Cog.Models
  alias Cog.MessageTranslations

  def handle_message(req, state) do
    result = case req.options do
               %{"create" => true} -> create_group(req.args)
               %{"drop" => true} -> drop_group(req.args)
               %{"add" => true} -> modify_group(req)
               %{"remove" => true} -> modify_group(req)
               %{"list" => true} -> list_all_groups
               _ ->
                 {:error, "I am not sure what action you want me to take using `group`"}
             end
    case result do
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, message} ->
        {:error, req.reply_to, message, state}
    end
  end

  defp create_group([]),
    do: MessageTranslations.translate_error("Missing name", {:fail_creation, ""})
  defp create_group([name | _]) do
    case Repo.get_by(Group, name: name) do
      nil ->
        case Group.changeset(%Group{}, %{name: name}) |> Repo.insert do
          {:ok, group} -> MessageTranslations.translate_success(%{action: :create, entity: group})
          {:error, errmsg} -> MessageTranslations.translate_error(errmsg, {:fail_creation, name})
        end
      %Group{} ->
        MessageTranslations.translate_error("group", {:already_exists, name})
    end
  end

  defp drop_group([name | _]) do
    case Repo.get_by(Group, name: name) do
      %Group{}=group ->
        Repo.delete!(group)
        MessageTranslations.translate_success(%{action: :drop, entity: group})
      nil -> MessageTranslations.translate_error("group", {:does_not_exists, name})
    end
  end

  defp modify_group(req) do
    admitter = validate(req)
    case admitter.errors do
      [] ->
        perform_action(admitter.action, admitter)
        |> return_results(admitter)
      _ -> return_results(:error, admitter)
    end
  end

  defp list_all_groups do
    result = Repo.all(Group)
    case result do
      [] -> {:ok, "Currently, there are no groups in the system."}
      _ -> {:ok, format_list(result, "")}
    end
  end

  defp format_list([], acc) do
    "The following are the available groups: \n#{acc}"
  end
  defp format_list([%{name: name} | remaining], acc) do
    format_list(remaining, "* #{name}\n" <> acc)
  end

  defp perform_action(:add, admitter) do
    Groupable.add_to(admitter.entity, admitter.classification)
  end
  defp perform_action(:remove, admitter) do
    Groupable.remove_from(admitter.entity, admitter.classification)
  end

  defp return_results(:ok, admitter), do: MessageTranslations.translate_success(admitter)
  defp return_results({:error, :forbidden_group_cycle}, _admitter) do
    # This is a stop-gap, pending a larger refactoring
    {:error, "This operation would create a circular group relationship (e.g. A is-a-member-of B, B is-a-member-of A), which is forbidden"}
  end
  defp return_results(_, admitter) do
    [error | _] = admitter.errors
    MessageTranslations.translate_error("group", error)
  end

  defp validate(req) do
    %MessageTranslations{req: req}
    |> validate_action
    |> validate_groupable
    |> validate_group
  end

  defp validate_action(%{req: req, errors: errors}=input) do
    case req.options do
      %{"add" => true} -> %{input | action: :add}
      %{"remove" => true} -> %{input | action: :remove}
      _ -> %{input | errors: [:missing_action | errors]}
    end
  end

  defp validate_groupable(%{req: %{options: %{"user" => username}}, errors: errors}=input) do
    case Repo.get_by(User, username: username) do
      %User{}=user -> %{input | entity: user}
      nil -> %{input | errors: [{:unrecognized_user, username} | errors]}
    end
  end
  defp validate_groupable(%{req: %{options: %{"group" => name}}, errors: errors}=input) do
    case Repo.get_by(Group, name: name) do
      %Group{}=group -> %{input | entity: group}
      nil -> %{input | errors: [{:unrecognized_group, name} | errors]}
    end
  end
  defp validate_groupable(%{req: %{options: _}, errors: errors}=input),
    do: %{input | errors: [:missing_target | errors]}

  defp validate_group(%{req: %{args: []}, errors: errors}=input) do
    %{input | errors: [:missing_group | errors]}
  end
  defp validate_group(%{req: %{args: [name | _]}, errors: errors}=input) do
    case Repo.get_by(Group, name: name) do
      %Group{}=group -> %{input | classification: group}
      nil -> %{input | errors: [{:unrecognized_group, name} | errors]}
    end
  end

end
