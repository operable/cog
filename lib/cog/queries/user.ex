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
end
