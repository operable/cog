defmodule Cog.ErrorResponse do
  alias Piper.Permissions.Ast
  alias Cog.Models.Bundle

  def render({:parse_error, msg}) when is_binary(msg),
    do: msg
  def render({:redirect_error, invalid}),
    do: redirection_error_message(invalid)
  def render({:binding_error, {:missing_key, var}}),
    do: "I can't find the variable '$#{var}'."
  def render({:binding_error, msg}) when is_binary(msg),
    do: msg
  def render({:no_rule, current_invocation}),
    do: "No rules match the supplied invocation of '#{current_invocation}'. Check your args and options, then confirm that the proper rules are in place."
  def render({:denied, {%Ast.Rule{}=rule, current_invocation}}) do
    perms = Enum.map(Ast.Rule.permissions_used(rule), &("'#{&1}'")) |> Enum.join(", ")
    "Sorry, you aren't allowed to execute '#{current_invocation}'.\nYou will need at least one of the following permissions to run this command: #{perms}."
  end
  def render({:no_relays, bundle_name}) do # TODO: Add version, too?
    "No Cog Relays supporting the `#{bundle_name}` bundle are currently online. " <>
    "If you just assigned the bundle to a relay group you will need to wait for the relay refresh interval to pick up the new bundle."
  end
  def render({:no_relay_group, bundle_name}),
    do: "Bundle '#{bundle_name}' is not assigned to a relay group. Assign the bundle to a relay group and try again."
  def render({:no_enabled_relays, bundle_name}) do # TODO: Should we print the list of disabled relays?
    "No Cog Relays supporting the `#{bundle_name}` bundle are currently available. " <>
    "There are one or more relays serving the bundle, but they are disabled. Enable an appropriate relay and try again."
  end
  def render({:disabled_bundle, %Bundle{name: name}}),
    do: "The #{name} bundle is currently disabled"
  def render({:timeout, full_command_name}),
    do: "The #{full_command_name} command timed out"
  def render({:template_rendering_error, {error, template, adapter}}),
    do: "There was an error rendering the template '#{template}' for the adapter '#{adapter}': #{inspect error}"
  def render({:command_error, response}) do
    error = response.status_message || response.body["message"]
    error
  end

  # `errors` is a keyword list of [reason: name] for all bad redirect
  # destinations that were found. `name` is the value as originally
  # typed by the user.
  defp redirection_error_message(errors) do
    all_bad_redirects = errors
    |> Enum.map(fn({_,r}) -> r end)

    main_message = """

    No commands were executed because the following redirects are invalid:

    #{all_bad_redirects |> Enum.join(", ")}
    """
    not_a_member = errors
    |> Enum.filter_map(
      fn({k,_}) -> k == "not_a_member" end,
      fn({_,v}) -> v end
    )

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
