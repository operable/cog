defmodule Cog.Gatekeeper do
  @moduledoc """
    Consult the Gatekeeper to determine if a User has Permission to
    carry out a 'bot action.
  """
  use Cog.Models

  def user_is_permitted?(user, permission) do
    User.has_permission(user, permission)
  end

end
