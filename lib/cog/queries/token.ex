defmodule Cog.Queries.Token do

  import Ecto.Query, only: [from: 2]

  alias Cog.Models.Token

  @doc """
  Retrieve all expired tokens (those that are older than
  `ttl_in_seconds`)
  """
  def expired(ttl_in_seconds) do
    from t in Token,
    where: datetime_add(t.inserted_at, ^ttl_in_seconds, "second") <= ^Ecto.DateTime.utc
  end
end
