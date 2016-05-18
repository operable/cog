defmodule Cog.Commands.Group do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Commands.Group

  Helpers.usage :root, """
  Manage user groups

  USAGE
    group [FLAGS] <SUBCOMMAND>

  SUBCOMMANDS
    list      List user groups (Default)
    info      Get info about a specific user group
    create    Creates a new user group
    delete    Deletes a user group
    member    Manage members of user groups
    role      Manage roles associated with user groups

  FLAGS
    -h, --help    Display this usage info
  """

  permission "manage_groups"
  permission "manage_users"

  rule ~s(when command is #{Cog.embedded_bundle}:group must have #{Cog.embedded_bundle}:manage_groups)
  rule ~s(when command is #{Cog.embedded_bundle}:group with arg[0] == 'member' must have #{Cog.embedded_bundle}:manage_users)

  # list options
  option "verbose", type: "bool", short: "v"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
      "list" ->
        Group.List.list_groups(req, args)
      "create" ->
        Group.Create.create_group(req, args)
      "delete" ->
        Group.Delete.delete_group(req, args)
      "member" ->
        Group.Member.manage_members(req, args)
      "role" ->
        Group.Role.manage_roles(req, args)
      "info" ->
        Group.Info.get_info(req, args)
      nil ->
        if Helpers.flag?(req.options, "help") do
          show_usage
        else
          Group.List.list_groups(req, args)
        end
      invalid ->
        suggestion = Enum.max_by(["list", "create", "delete", "member", "role", "info"],
                                 &String.jaro_distance(&1, invalid))
        show_usage(error({:unknown_subcommand, invalid, suggestion}))
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  defp error(:required_subcommand),
    do: "You must specify a subcommand. Please specify one of, 'list', 'create', 'delete' or 'member'"
  defp error({:unknown_subcommand, invalid, suggestion}),
    do: "Unknown subcommand '#{invalid}'. Did you mean '#{suggestion}'?"
end

    #result = case req.options do
               #%{"create" => true} -> create_group(req.args)
               #%{"drop" => true} -> drop_group(req.args)
               #%{"add" => true} -> modify_group(req)
               #%{"remove" => true} -> modify_group(req)
               #%{"list" => true} -> list_all_groups
               #_ ->
                 #{:error, "I am not sure what action you want me to take using `group`"}
             #end
    #case result do
      #{:ok, message} ->
        #{:reply, req.reply_to, message, state}
      #{:error, message} ->
        #{:error, req.reply_to, message, state}
    #end
  #end

  #defp create_group([]),
    #do: MessageTranslations.translate_error("Missing name", {:fail_creation, ""})
  #defp create_group([name | _]) do
    #case Repo.get_by(Group, name: name) do
      #nil ->
        #case Group.changeset(%Group{}, %{name: name}) |> Repo.insert do
          #{:ok, group} -> MessageTranslations.translate_success(%{action: :create, entity: group})
          #{:error, errmsg} -> MessageTranslations.translate_error(errmsg, {:fail_creation, name})
        #end
      #%Group{} ->
        #MessageTranslations.translate_error("group", {:already_exists, name})
    #end
  #end

  #defp drop_group([name | _]) do
    #case Repo.get_by(Group, name: name) do
      #%Group{}=group ->
        #Repo.delete!(group)
        #MessageTranslations.translate_success(%{action: :drop, entity: group})
      #nil -> MessageTranslations.translate_error("group", {:does_not_exists, name})
    #end
  #end

  #defp modify_group(req) do
    #admitter = validate(req)
    #case admitter.errors do
      #[] ->
        #perform_action(admitter.action, admitter)
        #|> return_results(admitter)
      #_ -> return_results(:error, admitter)
    #end
  #end

  #defp list_all_groups do
    #result = Repo.all(Group)
    #case result do
      #[] -> {:ok, "Currently, there are no groups in the system."}
      #_ -> {:ok, format_list(result, "")}
    #end
  #end

  #defp format_list([], acc) do
    #"The following are the available groups: \n#{acc}"
  #end
  #defp format_list([%{name: name} | remaining], acc) do
    #format_list(remaining, "* #{name}\n" <> acc)
  #end

  #defp perform_action(:add, admitter) do
    #Groupable.add_to(admitter.entity, admitter.classification)
  #end
  #defp perform_action(:remove, admitter) do
    #Groupable.remove_from(admitter.entity, admitter.classification)
  #end

  #defp return_results(:ok, admitter),
    #do: MessageTranslations.translate_success(admitter)
  #defp return_results(_, admitter) do
    #[error | _] = admitter.errors
    #MessageTranslations.translate_error("group", error)
  #end

  #defp validate(req) do
    #%MessageTranslations{req: req}
    #|> validate_action
    #|> validate_groupable
    #|> validate_group
  #end

  #defp validate_action(%{req: req, errors: errors}=input) do
    #case req.options do
      #%{"add" => true} -> %{input | action: :add}
      #%{"remove" => true} -> %{input | action: :remove}
      #_ -> %{input | errors: [:missing_action | errors]}
    #end
  #end

  #defp validate_groupable(%{req: %{options: %{"user" => username}}, errors: errors}=input) do
    #case Repo.get_by(User, username: username) do
      #%User{}=user -> %{input | entity: user}
      #nil -> %{input | errors: [{:unrecognized_user, username} | errors]}
    #end
  #end
  #defp validate_groupable(%{req: %{options: _}, errors: errors}=input),
    #do: %{input | errors: [:missing_target | errors]}

  #defp validate_group(%{req: %{args: []}, errors: errors}=input) do
    #%{input | errors: [:missing_group | errors]}
  #end
  #defp validate_group(%{req: %{args: [name | _]}, errors: errors}=input) do
    #case Repo.get_by(Group, name: name) do
      #%Group{}=group -> %{input | classification: group}
      #nil -> %{input | errors: [{:unrecognized_group, name} | errors]}
    #end
  #end

#end
