defmodule Cog.Commands.Role do
  alias Cog.Commands.Helpers

  def error({:permanent_role_grant, role_name, group_name}),
    do: "Cannot revoke role #{inspect role_name} from group #{inspect group_name}: grant is permanent"
  def error({:protected_role, name}),
    do: "Cannot alter protected role #{name}"
  def error(:wrong_type), # TODO: put this into helpers, take it out of permission.ex
    do: "Arguments must be strings"
  def error(error),
    do: Helpers.error(error)
end
