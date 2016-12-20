defmodule Cog.Commands.Rule do

  alias Cog.Commands.Helpers

  def error({:disabled, command}),
    do: "#{command} is not enabled. Enable a bundle version and try again"
  def error({:command_not_found, command}),
    do: "Command #{inspect command} could not be found"
  def error({:ambiguous, command}),
    do: "Command #{inspect command} refers to multiple commands. Please include a bundle in a fully qualified command name."
  def error({:rule_invalid, {:invalid_rule_syntax, error}}),
    do: "Could not create rule: #{inspect error}"
  def error({:rule_invalid, {:unrecognized_command, command}}),
    do: "Could not create rule: Unrecognized command #{inspect command}"
  def error({:rule_invalid, {:unrecognized_permission, permission}}),
    do: "Could not create rule: Unrecognized permission #{inspect permission}"
  def error({:rule_invalid, {:permission_bundle_mismatch, _permission}}),
    do: "Could not create rule with permission outside of command bundle or the \"site\" namespace"
  def error({:rule_invalid, error}),
    do: "Could not create rule: #{inspect error}"
  def error({:rule_not_found, [uuid]}),
    do: "Rule #{inspect uuid} could not be found"
  def error({:rule_not_found, uuids}),
    do: "Rules #{Enum.map_join(uuids, ", ", &inspect/1)} could not be found"
  def error({:rule_uuid_invalid, uuid}),
    do: "Invalid UUID #{inspect uuid}"
  def error(:wrong_type),
    do: "Argument must be a string"
  def error(error),
    do: Helpers.error(error)
end
