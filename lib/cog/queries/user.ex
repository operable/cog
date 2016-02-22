defmodule Cog.Queries.User do
  use Cog.Queries

  def for_handle(handle, provider) when is_binary(provider) do
    from u in User,
    join: ch in assoc(u, :chat_handles),
    join: cp in assoc(ch, :chat_provider),
    where: ch.handle == ^handle and cp.name == ^provider,
    preload: [:chat_handles]
  end

  @doc """
  Given a user id, returns the list of chat handles.
  """
  def handles(user_id) do
    from c in ChatHandle,
    where: c.user_id == ^user_id,
    preload: [:chat_provider]
  end

  @doc """
  Given a `username` and `password`, find the User they belong to.
  The `password` is encoded and queried against the `password_digest`
  field along with the `username`.

  If the user does not exist or the password is invalid, the query
  returns nothing.
  """
  def for_username_password(username, password) do
    from u in Cog.Models.User,
    where: u.username == ^username and u.password_digest == ^Cog.Passwords.encode(password),
    select: u
  end

  @doc """
  Given a `token`, find the User it belongs to. `ttl_in_seconds` is
  the current amount of time that a token can be considered valid; if
  it was inserted more than `ttl_in_seconds` seconds in the past, it
  is considered expired.

  If the token exists in the system, this query will return a tuple of
  the type `{%User{}, boolean}`, where the boolean value indicates
  whether the token is still valid.

  If the token does not exist in the system, the query returns nothing.
  """
  def for_token(token, ttl_in_seconds) do
    from u in User,
    join: t in assoc(u, :tokens),
    where: t.value == ^token,
    select: {u, datetime_add(t.inserted_at, ^ttl_in_seconds, "second") > ^Ecto.DateTime.utc}
  end

  @doc """
  Chainable query fragment that selects all users that have a
  given permission, whether directly, by role, or by (recursive) group
  membership, or any combination thereof.

  The queryable that is given must ultimately resolve to a user, and
  if not given, defaults to the `User` model for maximum flexibility
  """
  def with_permission(queryable \\ User, %Permission{}=permission) do
    id = Cog.UUID.uuid_to_bin(permission.id)
    from u in queryable,
    # TODO: Use a fragment join instead?
    where: u.id in fragment("SELECT * FROM users_with_permission(?)", ^id)
  end

  @doc """
  Chainable query fragment that selects all users that have a
  chat handle for a given chat provider.

  The queryable that is given must ultimately resolve to a user, and
  if not given, defaults to the `User` model for maximum flexibility
  """
  # TODO: This is identical to `for_handle/2` but without the
  #     where: ch.handle == ^handle
  # fragment
  def with_chat_handle_for(queryable \\ User, provider) do
    from u in queryable,
    join: ch in assoc(u, :chat_handles),
    join: cp in assoc(ch, :chat_provider),
    where: cp.name == ^provider,
    preload: [chat_handles: ch]
  end

end
