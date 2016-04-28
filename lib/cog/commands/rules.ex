defmodule Cog.Commands.Rules do
  @moduledoc """
  This command allows the user to manage rules for commands.

  Format:
    Rules -
      rules --add "when command is <full_command_name> must have <namespace>:<permission>"
      rules --add --for-command=<full_command_name> --permission=<namespace>:<permission>
      rules --list --for-command=<full_command_name>
      rules --drop --for-command=<full_command_name>
      rules --drop --id=<rule_id>

  Examples:
  > @bot operable:rules --add "when command is operable:ec2-terminate must have operable:ec2"
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  alias Cog.Command.Request

  option "add", type: "bool"
  option "list", type: "bool"
  option "drop", type: "bool"
  option "id", type: "string"
  option "permission", type: "string"
  option "for-command", type: "string"

  permission "manage_commands"

  rule "when command is #{Cog.embedded_bundle}:rules must have #{Cog.embedded_bundle}:manage_commands"

  alias Piper.Permissions.Parser
  alias Cog.Repo
  require Logger

  defstruct [req: nil,
             action: nil,
             permission: nil,
             command: nil,
             id: nil,
             expression: nil,
             errors: [],
             rules: [],
            ]

  def handle_message(req, state) do
    # TODO: Need to do non-add stuff inside a transaction
    # TODO: investigate nested transaction for rule ingestion

    case req |> validate |> execute |> format do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, message} ->
        {:error, req.reply_to, message, state}
    end
  end

  # Ensure that all data given in the invocation is consistent and
  # acceptable before executing the action
  @spec validate(%Request{}) :: %__MODULE__{}
  defp validate(req) do
    %__MODULE__{req: req}
    |> verify_one_action
    |> validate_action
    |> validate_input
  end

  # Ensure that the user has specified only one action; if not, file
  # an error.
  @spec verify_one_action(%__MODULE__{}) :: %__MODULE__{}
  defp verify_one_action(%__MODULE__{req: req}=state) do
    values = ["add", "list", "drop"]
    |> Enum.map(&Map.get(req.options, &1))
    |> Enum.reject(&is_nil/1)

    case values do
      [true] ->
        state
      [] ->
        add_errors(state, :unrecognized_action)
      _ ->
        add_errors(state, :too_many_actions_specified)
    end
  end

  # Determine the specific action the user is requesting. Perform only
  # enough validation to determine that a user has requested a valid
  # option.
  @spec validate_action(%__MODULE__{}) :: %__MODULE__{}
  defp validate_action(%__MODULE__{errors: [_|_]}=state),
    do: state
  defp validate_action(%__MODULE__{req: %Request{options: %{"add" => true}}=req}=state) do
    case req.args do
      [] ->
        %{state | action: {:add, :assemble_rule}}
      [_] ->
        %{state | action: {:add, :expression}}
      [_ | _] ->
        add_errors(state, {:too_many_args, :add, 1})
    end
  end
  defp validate_action(%__MODULE__{req: %Request{options: %{"list" => true}}}=state),
    do: %{state | action: :list}
  defp validate_action(%__MODULE__{req: %Request{options: %{"drop" => true}}=req}=state) do
    case req.options do
      %{"id" => id} ->
        %{state | action: {:drop, :by_id}, id: id}
      %{"for-command" => _} ->
        %{state | action: {:drop, :by_command}}
      _ ->
        add_errors(state, {:missing_options, :drop})
    end
  end

  # Once the action being performed by the invocation has been
  # validated, we can begin to validate the options and arguments
  # given by the user, ensuring they are valid for the requested
  # action. This includes ensuring all required data is present, that
  # it is of the correct type, that it is mutually compatible, etc.
  @spec validate_input(%__MODULE__{}) :: %__MODULE__{}
  defp validate_input(%__MODULE__{errors: [_|_]}=state),
    do: state
  defp validate_input(%__MODULE__{action: {:drop, :by_id}, id: id}=state) do
    if Cog.UUID.is_uuid?(id) do
      state
    else
      add_errors(state, {:wrong_type, {:option, :id}, :UUID, id})
    end
  end
  defp validate_input(%__MODULE__{req: req, action: action}=state) when action in [:list, {:drop, :by_command}] do
    case get_command(req.options) do
      {:ok, command} ->
        case resolve_command(command) do
          nil ->
            add_errors(state, {:unrecognized_command, command})
          _ ->
            # TODO: consider capturing this Command model and using
            # that in place of the name?
            %{state | command: command}
        end
      error ->
        add_errors(state, error)
    end
  end
  defp validate_input(%__MODULE__{req: req, action: {:add, :expression}}=state) do
    case req.args do
      [expr] when is_binary(expr) ->
        %{state | expression: expr}
      [bad_expr] ->
        add_errors(state, {:wrong_type, {:argument, "<expression>"}, :string, bad_expr})
    end
  end
  defp validate_input(%__MODULE__{req: req, action: {:add, :assemble_rule}}=state) do
    # We don't check that the specified command and permission exist
    # here, because that is done in the course of rule ingestion.
    command = get_command(req.options)

    permission = case req.options["permission"] do
                   nil ->
                     :missing_permission
                   value when is_binary(value) ->
                     if is_qualified?(value) do
                       {:ok, value}
                     else
                       :permission_not_qualfied
                     end
                   bad_value ->
                     {:wrong_type, {:option, :permission}, :string, bad_value}
                 end

    case {command, permission} do
      {{:ok, command}, {:ok, permission}} ->
        if is_permission_valid?(command, permission) do
          %{state | command: command, permission: permission}
        else
          add_errors(state, :invalid_permission_namespace)
        end
      {{:ok, _}, permission_error} ->
        add_errors(state, permission_error)
      {command_error, {:ok, _}} ->
        add_errors(state, command_error)
      {command_error, permission_error} ->
        add_errors(state, [command_error, permission_error])
    end
  end

  # Once all the input has been verified, if no errors were uncovered,
  # perform the requested action.
  @spec execute(%__MODULE__{}) :: %__MODULE__{}
  defp execute(%{errors: [_|_]}=state),
    do: state
  defp execute(%__MODULE__{action: {:add, :expression}}=state) do
    case Cog.RuleIngestion.ingest(state.expression) do
      {:ok, rule} ->
        %{state | rules: [rule]}
      {:error, errors} ->
        add_errors(state, errors)
    end
  end
  defp execute(%__MODULE__{action: {:add, :assemble_rule}}=state) do
    case Cog.RuleIngestion.ingest("when command is #{state.command} must have #{state.permission}") do
      {:ok, rule} ->
        %{state | rules: [rule]}
      {:error, errors} ->
        add_errors(state, errors)
    end
  end
  defp execute(%__MODULE__{action: :list, command: command}=state) do
    rules = command
    |> Cog.Queries.Command.rules_for_cmd
    |> Repo.all
    %{state | rules: rules}
  end
  defp execute(%__MODULE__{action: {:drop, :by_id}, id: id}=state) do
    case Repo.get_by(Cog.Models.Rule, id: id) do
      nil ->
        add_errors(state, {:missing_rule, id})
      rule ->
        Repo.delete!(rule)
        %{state | rules: [rule]}
    end
  end
  defp execute(%__MODULE__{action: {:drop, :by_command}, command: command}=state) do
    query = Cog.Queries.Command.rules_for_cmd(command)
    case Repo.all(query) do
      [] ->
        %{state | rules: []}
      rules ->
        Repo.delete_all(query)
        %{state | rules: rules}
    end
  end

  # For each possible action that was executed, transform the successful
  # results as appropriate, returning a tuple indicating the template
  # used to format the results, or an error message string
  @spec format(%__MODULE__{}) :: {:ok, String.t, term} | {:error, String.t}
  defp format(%__MODULE__{errors: [_|_]=errors}) do
    # Ideally, I want to just return a list of error strings back to
    # the executor and have it do this formatting for me.
    error_strings = errors
    |> Enum.map(&translate_error/1)
    |> Enum.map(&("* #{&1}\n"))
    {:error, """

             #{error_strings}
             """}
  end
  defp format(%__MODULE__{action: {:add, _}, rules: [rule]}),
    do: {:ok, "rules-add", to_output_data(rule)}
  defp format(%__MODULE__{action: {:drop, _}, rules: rules}),
    do: {:ok, "rules-drop", Enum.map(rules, &to_output_data/1)}
  defp format(%__MODULE__{action: :list, rules: rules}),
    do: {:ok, "rules-list", Enum.map(rules, &to_output_data/1)}

  ########################################################################
  # Utility Functions

  # Shorthand for adding one or more errors to a `%__MODULE__{}`
  # instance's `errors` list
  defp add_errors(input, error_or_errors),
    do: Map.update!(input, :errors, &Enum.concat(&1, List.wrap(error_or_errors)))

  # Extract a command from an options map, determining if it is
  # syntactically valid or not.
  defp get_command(%{"for-command" => command}) when is_binary(command) do
    if is_qualified?(command) do
      {:ok, command}
    else
      :command_not_qualfied
    end
  end
  defp get_command(%{"for-command" => bad_command}),
    do: {:wrong_type, {:option, "for-command"}, :string, bad_command}
  defp get_command(_options),
    do: :missing_command

  # Determine if a permission or command name is properly qualified
  # (i.e, is a colon-delimited name with two parts).
  defp is_qualified?(value) do
    case String.split(value, ":") do
      [_,_] -> true
      _ -> false
    end
  end

  # Permissions may only come from the command's own bundle or from
  # the `site` namespace; anything else promotes a fragile dependency
  # among bundles, and is explicitly disallowed.
  defp is_permission_valid?(command, permission) do
    [bundle, _command_name] = String.split(command, ":")
    [namespace, _permission_name] = String.split(permission, ":")

    namespace in [bundle, Cog.site_namespace]
  end

  # Convert error tuples and atoms into strings
  defp translate_error({:too_many_args, command, expected_num}),
    do: "The `--#{command}` action expects #{expected_num} argument#{if expected_num > 1, do: "s", else: ""}"
  defp translate_error({:missing_options, :drop}),
    do: "The `--drop` action expects either an `--id` option or a `--for-command` option"
  defp translate_error(:unrecognized_action),
    do: "You must specify either an `--add`, `--drop`, or `--list` action"
  defp translate_error(:too_many_actions_specified),
    do: "You must specify only one of `--add`, `--drop`, or `--list` as an action"
  defp translate_error({:wrong_type, {opt_or_arg, opt_or_arg_name}, desired_type, given_value}),
    do: "The #{opt_or_arg} `#{opt_or_arg_name}` must be a #{desired_type}; you gave `#{inspect given_value}`"
  defp translate_error(:missing_permission),
    do: "You must specify a `--permission` option"
  defp translate_error(:missing_command),
    do: "You must specify a `--for-command` option"
  defp translate_error(:permission_not_qualfied),
    do: "The value of the `--permission` option must be a fully-qualified permission, like `site:admin`"
  defp translate_error(:invalid_permission_namespace),
    do: "The namespace of the permission must either be `site` or the bundle from which the command comes"
  defp translate_error(:command_not_qualfied),
    do: "The value of the `--for-command` option must be a bundle-qualified command, like `operable:help`"
  defp translate_error({:missing_rule, id}),
    do: "There are no rules with the ID `#{id}`"
  defp translate_error({:unrecognized_command, command}),
    do: "Could not find command `#{command}`"
  defp translate_error({:unrecognized_permission, name}),
    do: "Could not find permission `#{name}`"
  defp translate_error({:no_dupes, _}),
    do: "Rule already exists"
  defp translate_error({:invalid_rule_syntax, msg}),
    do: "Invalid rule: #{msg}"
  defp translate_error(error),
    do: "#{inspect error}"

  # Convert a Rule model into the Map data structure we return from
  # the command
  defp to_output_data(%Cog.Models.Rule{}=rule) do
    ast = Parser.json_to_rule!(rule.parse_tree)
    %{id: rule.id,
      command: ast.command,
      rule: "#{ast}"}
  end

  defp resolve_command(given_name),
    do: given_name |> Cog.Queries.Command.named |> Repo.one

end
