defprotocol Permittable do
  @moduledoc """
  Anything that can have a permission associated with it should
  implement this!
  """

  @doc """
  Grants `permission` directly to `grantee`; that is, no intermediate
  group memberships are involved.
  """
  def grant_to(grantee, permission)

  def revoke_from(grantee, permission)
end
