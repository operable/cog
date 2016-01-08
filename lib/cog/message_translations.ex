defmodule Cog.MessageTranslations do
  use Cog.Models

  defstruct req: nil, action: nil, entity: nil, classification: nil, errors: []

  def translate_success(%{action: :create, entity: entity}),
    do: "The #{type(entity)} `#{name(entity)}` has been created."
  def translate_success(%{action: :drop, entity: entity}),
    do: "The #{type(entity)} `#{name(entity)}` has been deleted."
  def translate_success(%{req: req, action: :add, entity: entity, classification: classification}) do
    [_ns, command] = String.split(req.command, ":")
    "Added the #{type(entity)} `#{name(entity)}` to the #{command} `#{classification.name}`"
  end
  def translate_success(%{req: req, action: :remove, entity: entity, classification: classification}) do
    [_ns, command] = String.split(req.command, ":")
    "Removed the #{type(entity)} `#{name(entity)}` from the #{command} `#{classification.name}`"
  end
  def translate_success(%{action: :grant, entity: entity, classification: classification}) do
    "Granted #{type(classification)} `#{classification.name}` to #{type(entity)} `#{name(entity)}`"
  end
  def translate_success(%{action: :revoke, entity: entity, classification: classification}) do
    "Revoked #{type(classification)} `#{classification.name}` from #{type(entity)} `#{name(entity)}`"
  end

  def type(%User{}), do: "user"
  def type(%Group{}), do: "group"
  def type(%Role{}), do: "role"

  def name(%User{username: name}), do: name
  def name(%Group{name: name}), do: name
  def name(%Role{name: name}), do: name

  def translate_error(errmsg, {:fail_creation, name}),
    do: "ERROR! Unable to create `#{name}`:\n#{errmsg}"
  def translate_error(command, {:fail_deletion, name}),
    do: "ERROR! Unable to delete #{command} `#{name}`."
  def translate_error(command, {:already_exists, name}),
    do: "ERROR! The #{command} `#{name}` already exists."
  def translate_error(command, {:does_not_exists, name}),
    do: "ERROR! The #{command} `#{name}` does not exist."
  def translate_error(command, :missing_action),
    do: "ERROR! Must specify an action. See `operable:help operable:#{command}` for more info"
  def translate_error(_command, {:unrecognized_user, name}),
    do: "ERROR! Could not find user `#{name}`"
  def translate_error(_command, {:unrecognized_group, name}),
    do: "ERROR! Could not find group `#{name}`"
  def translate_error(_command, {:unrecognized_role, name}),
    do: "ERROR! Could not find role `#{name}`"
  def translate_error(_command, :missing_user),
    do: "ERROR! Must specify a user"
  def translate_error(_command, :missing_group),
    do: "ERROR! Must specify a group to modify."
  def translate_error(_command, :missing_role),
    do: "ERROR! Must specify a role to modify."
  def translate_error(command, :missing_target),
    do: "ERROR! Must specify a target to act upon. See `operable:help operable:#{command}` for more details."
  def translate_error(_command, {:unrecognized_permission, name}),
    do: "ERROR! Could not find permission `#{name}`"
  def translate_error(command, _),
    do: "ERROR! Badly formed command. Please try again. Type `operable:help operable:#{command}` for help."

end
