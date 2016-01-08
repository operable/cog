defmodule Cog.Passwords.Test do
  use ExUnit.Case
  alias Cog.Passwords

  setup do
    plaintext = "monkeys"
    encoded = Passwords.encode(plaintext)
    {:ok, [plaintext: plaintext,
           encoded: encoded]}
  end

  test "an encoded password can be matched correctly",
  %{plaintext: plaintext, encoded: encoded} do
    assert Passwords.matches?(plaintext, encoded)
  end

  test "an incorrect password will not match", %{plaintext: plaintext, encoded: encoded} do
    wrong_password = "not the right password"
    assert wrong_password != plaintext
    refute Passwords.matches?(wrong_password, encoded)
  end

  test "a missing password never matches", %{encoded: encoded} do
    refute Passwords.matches?(nil, encoded)
  end

end
