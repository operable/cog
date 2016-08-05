defmodule Cog.AuditMessage do
  alias Cog.Models.Bundle
  alias Cog.Models.CommandVersion
  alias Cog.ErrorResponse

  # Turn an error tuple into a message intended for the audit log
  def render({:parse_error, msg}, request) when is_binary(msg),
    do: "Error parsing command pipeline '#{request.text}': #{msg}"
  def render({:redirect_error, invalid}, _request),
    do: "Invalid redirects were specified: #{inspect invalid}"
  def render({:binding_error, {:missing_key, var}}, request),
    do: "Error preparing to execute command pipeline '#{request.text}': Unknown variable '#{var}'"
  def render({:binding_error, msg}, request) when is_binary(msg) do
    # TODO: Pretty sure this is not what we want, ultimately... this
    # is coming from plan_next_invocation, not some top-level place
    "Error preparing to execute command pipeline '#{request.text}': #{msg}"
  end
  def render({:denied, {_rule, current_invocation}}, request),
    do: "User #{request.sender["handle"]} denied access to '#{current_invocation}'"
  def render({:no_relays, bundle_name}, _request),
    do: ErrorResponse.render({:no_relays, bundle_name}) # Uses same user message for now
  def render({:disabled_bundle, %Bundle{name: name}}, _request),
    do: "The #{name} bundle is currently disabled"
  def render({:command_error, response}, _request),
    do: response.status_message || response.body["message"]
  def render({:template_rendering_error, {error, template, adapter}}, _request),
    do: "Error rendering template '#{template}' for '#{adapter}': #{inspect error}"
  def render({:timeout, %CommandVersion{}=command}, _request) do
    name = CommandVersion.full_name(command)
    "Timed out waiting on #{name} to reply"
  end
  def render({:abort_pipeline, full_command_name}, _request) do
    "Command #{full_command_name} aborted pipeline execution."
  end
  def render({:timeout, command_name}, _request) do
    "Timed out waiting on #{command_name} to reply"
  end
  def render({:no_rule, current_invocation}, _request),
    do: "No rule matching '#{current_invocation}'"
end
