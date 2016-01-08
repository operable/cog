defmodule TokenTest do
  use Cog.ModelCase
  use Cog.Models
  alias Cog.Repo

  setup do
    user = user("cog")
    {:ok, [user: user]}
  end

  test "inserting a new token for a user", %{user: user} do
    pre_token_user = Repo.preload(user, :tokens)
    assert(pre_token_user.tokens == [])

    {:ok, token} = Token.insert_new(user, %{value: "something"})
    assert(token.user_id == user.id)
    post_token_user = Repo.preload(user, :tokens)
    assert(token in post_token_user.tokens)
  end

  test "error received when trying to insert duplicate tokens", %{user: user} do
    {:ok, _} = Token.insert_new(user, %{value: "something"})
    {:error, changeset} = Token.insert_new(user, %{value: "something"})
    assert({:users_tokens_must_be_unique, "has already been taken"} in changeset.errors)
  end

  test "generate a random 64-bit unicode encoded string" do
    token_value = Token.generate
    assert(token_value != nil)
    second_token = Token.generate
    assert(token_value != second_token)
  end

end
