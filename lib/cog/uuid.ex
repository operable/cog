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

end
