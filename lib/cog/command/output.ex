defmodule Cog.Command.Output do

  alias Cog.Chat.Adapter
  alias Cog.Models.Bundle
  alias Cog.Template.Evaluator
  alias Piper.Permissions.Ast


  @doc """
  Utility function for sending data formatted by a common template
  (i.e., not a bundle-specific one) to a destination.

  If the targeted provider is a chat provider, the data is processed
  with the template to generate directives, which are then rendered to
  text by the provider. If it is not a chat provider (e.g., the "http"
  provider), no template rendering is performed, and the raw data
  itself is sent instead.
  """

  def send(common_template, message_data, room, provider, connection) do
    directives = Evaluator.evaluate(common_template, message_data)
    payload = if Adapter.is_chat_provider?(provider) do
      directives
    else
      message_data
    end

    Adapter.send(connection, provider, room, payload, %Cog.Chat.MessageMetadata{})
  end

  def format_error({:parse_error, msg}) when is_binary(msg),
    do: msg
  def format_error({:redirect_error, invalid}),
    do: redirection_error_message(invalid)
  def format_error({:binding_error, {:missing_key, var}}),
    do: "I can't find the variable '$#{var}'."
  def format_error({:binding_error, msg}) when is_binary(msg),
    do: msg
  def format_error({:no_rule, current_invocation}),
    do: "No rules match the supplied invocation of '#{current_invocation}'. Check your args and options, then confirm that the proper rules are in place."
  def format_error({:denied, {%Ast.Rule{} = rule, current_invocation}}) do
    perms = Enum.map(Ast.Rule.permissions_used(rule), &("'#{&1}'")) |> Enum.join(", ")
    "Sorry, you aren't allowed to execute '#{current_invocation}'.\nYou will need at least one of the following permissions to run this command: #{perms}."
  end
  def format_error({:no_relays, bundle_name}) do # TODO: Add version, too?
    "No Cog Relays supporting the `#{bundle_name}` bundle are currently online. " <>
    "If you just assigned the bundle to a relay group you will need to wait for the relay refresh interval to pick up the new bundle."
  end
  def format_error({:no_relay_group, bundle_name}),
    do: "Bundle '#{bundle_name}' is not assigned to a relay group. Assign the bundle to a relay group and try again."
  def format_error({:no_enabled_relays, bundle_name}) do # TODO: Should we print the list of disabled relays?
    "No Cog Relays supporting the `#{bundle_name}` bundle are currently available. " <>
    "There are one or more relays serving the bundle, but they are disabled. Enable an appropriate relay and try again."
  end
  def format_error({:disabled_bundle, %Bundle{name: name}}),
    do: "The #{name} bundle is currently disabled"
  def format_error({:timeout, full_command_name}),
    do: "The #{full_command_name} command timed out"
  def format_error({:template_rendering_error, {error, template, provider}}),
    do: "There was an error rendering the template '#{template}' for the provider '#{provider}': #{inspect error}"
  def format_error({:command_error, response}) do
      response.status_message || response.body["message"]
  end

  # `errors` is a keyword list of [reason: name] for all bad redirect
  # destinations that were found. `name` is the value as originally
  # typed by the user.
  defp redirection_error_message(errors) do
    all_bad_redirects = errors
    |> Enum.map(fn({_, r}) -> r end)

    main_message = """

    No commands were executed because the following redirects are invalid:

    #{all_bad_redirects |> Enum.join(", ")}
    """
    not_a_member = errors
    |> Enum.filter(fn({k, _}) -> k == "not_a_member" end)
    |> Enum.map(fn({_, v}) -> v end)

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
