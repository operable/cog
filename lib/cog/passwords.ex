defmodule Cog.Passwords do

  alias Comeonin.Bcrypt

  def encode(plaintext) do
    [salt: salt] = Application.get_env(:cog, __MODULE__, :salt)
    Bcrypt.hashpass(plaintext, salt)
  end

  def matches?(nil, _) do
    Bcrypt.dummy_checkpw()
  end

  def matches?(plaintext, hash) do
    Bcrypt.checkpw(plaintext, hash)
  end

end
