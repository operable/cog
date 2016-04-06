defmodule Cog.ErrorResponse do
  alias Piper.Permissions.Ast
  alias Cog.Models.Bundle
  alias Cog.Models.Command

  def render({:parse_error, msg}) when is_binary(msg),
    do: "Whoops! An error occurred. " <> msg
  def render({:redirect_error, invalid}),
    do: "Whoops! An error occurred. " <> redirection_error_message(invalid)
  def render({:binding_error, {:missing_key, var}}),
    do: "I can't find the variable '$#{var}'."
  def render({:binding_error, msg}) when is_binary(msg),
    do: "Whoops! An error occurred. " <> msg
  def render({:no_rule, current_invocation}),
    do: "No rules match the supplied invocation of '#{current_invocation}'. Check your args and options, then confirm that the proper rules are in place."
  def render({:denied, {%Ast.Rule{}=rule, current_invocation}}),
    do: "Sorry, you aren't allowed to execute '#{current_invocation}' :(\n You will need the '#{rule.permission_selector.perms.value}' permission to run this command."
  def render({:no_relays, %Bundle{name: name}}),
    do: "Whoops! An error occurred. No Cog Relays supporting the `#{name}` bundle are currently online"
  def render({:disabled_bundle, %Bundle{name: name}}),
    do: "Whoops! An error occurred. The #{name} bundle is currently disabled"
  def render({:timeout, %Command{}=command}) do
    name = Command.full_name(command)
    "The #{name} command timed out"
  end
  def render({:template_rendering_error, {error, template, adapter}}),
    do: "Whoops! An error occurred. There was an error rendering the template '#{template}' for the adapter '#{adapter}': #{inspect error}"
  def render({:command_error, response}) do
    error = response.status_message || response.body["message"]
    "Whoops! An error occurred. " <> error
  end

  # `errors` is a keyword list of [reason: name] for all bad redirect
  # destinations that were found. `name` is the value as originally
  # typed by the user.
  defp redirection_error_message(errors) do
    main_message = """

    No commands were executed because the following redirects are invalid:

    #{errors |> Keyword.values |> Enum.join(", ")}
    """

    not_a_member = Keyword.get_values(errors, :not_a_member)
    not_a_member_message = unless Enum.empty?(not_a_member) do
    """

    Additionally, the bot must be invited to these rooms before it can
    redirect to them:

    #{Enum.join(not_a_member, ", ")}
    """
    end

    # TODO: This is where I'd like to have error templates, so we can
    # be specific about recommending the conventions the user use to
    # refer to users and rooms
    ambiguous = Keyword.get_values(errors, :ambiguous)
    ambiguous_message = unless Enum.empty?(ambiguous) do
    """

    The following redirects are ambiguous; please refer to users and
    rooms according to the conventions of your chat provider
    (e.g. `@user`, `#room`):

    #{Enum.join(ambiguous, ", ")}
    """
    end

    # assemble final message
    message_fragments = [main_message,
                         not_a_member_message,
                         ambiguous_message]
    message_fragments
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end
end
