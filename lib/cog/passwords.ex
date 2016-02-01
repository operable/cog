defmodule Cog.Passwords do

  alias Comeonin.Bcrypt

  def encode(plaintext) do
    Bcrypt.hashpwsalt(plaintext)
  end

  def matches?(nil, _) do
    Bcrypt.dummy_checkpw()
  end

  def matches?(plaintext, hash) do
    Bcrypt.checkpw(plaintext, hash)
  end

end
