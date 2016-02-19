defmodule Cog.Passwords do
  alias Comeonin.Bcrypt

  @alpha Enum.concat ?A..?Z, ?a..?z
  @alphabet ',./!@#$%^&*();:?<>' ++ @alpha ++ '0123456789'

  def encode(plaintext) do
    Bcrypt.hashpwsalt(plaintext)
  end

  def matches?(nil, _) do
    Bcrypt.dummy_checkpw()
  end

  def matches?(plaintext, hash) do
    Bcrypt.checkpw(plaintext, hash)
  end

  def generate_password(length) do
    @alphabet
    |> Enum.take_random(length)
    |> to_string
  end
end
