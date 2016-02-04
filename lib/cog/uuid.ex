defmodule Cog.UUID do

  @doc """
  Ecto.UUID "UUID strings" don't appear to play well with
  `Postgrex.Extensions.Binary.encode/4`. This will transform them into
  a proper binary format that can be used in prepared statement
  arguments.
  """
  def uuid_to_bin(uuid) do
    {:ok, bin} = Ecto.UUID.dump(uuid)
    bin
  end

  @doc """
  Inverse of `uuid_to_bin/1` for completeness' sake.
  """
  def bin_to_uuid(bin) do
    {:ok, uuid} = Ecto.UUID.load(bin)
    uuid
  end

  @doc """

  Returns `true` if `maybe_uuid` is, in fact, a UUID.

  Examples:

      iex> Cog.UUID.is_uuid?(666)
      false

      iex> Cog.UUID.is_uuid?("nope")
      false

      iex> Cog.UUID.is_uuid?("0191f7da-60b2-46cf-83a8-b1169e4b69af")
      true

  """
  def is_uuid?(maybe_uuid) do
    try do
      UUID.info!(maybe_uuid)
      true
    rescue
      ArgumentError ->
        false
    end
  end

end
