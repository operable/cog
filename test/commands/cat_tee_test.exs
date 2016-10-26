defmodule Cog.Test.Commands.CatTeeTest do
  use Cog.AdapterCase, adapter: "test"

  @moduletag :skip

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "tee passes pipeline output through", %{user: user} do
    command = "@bot: seed '[{\"foo\":\"fooval\"}]' | tee myfoo"
    response = send_message(user, command)
    assert [%{foo: "fooval"}] = response
  end

  test "cat returns data saved by tee", %{user: user} do
    send_message(user, "@bot: seed '{\"foo\":\"fooval1\"}' | tee test")
    response = send_message(user, "@bot: cat test")
    assert [%{foo: "fooval1"}] = response
  end

  test "tee overwrites content for existing keys", %{user: user} do
    send_message(user, "@bot: seed '{\"foo\":\"fooval2\"}' | tee test")
    response = send_message(user, "@bot: cat test")
    assert [%{foo: "fooval2"}] = response
    response = send_message(user, "@bot: seed '{\"foo\":\"fooval3\"}' | tee test")
    assert [%{foo: "fooval3"}] = response
  end

  test "cat -m merges input with saved content", %{user: user} do
    send_message(user, "@bot: seed '{\"foo\":\"fooval4\"}' | tee test")
    response = send_message(user, "@bot: seed '{\"bar\":\"barval\"}' | cat -m test")
    assert [%{foo: "fooval4", bar: "barval"}] = response
  end

  test "cat -a append input to saved content", %{user: user} do
    send_message(user, "@bot: seed '{\"foo\":\"fooval5\"}' | tee test")
    response = send_message(user, "@bot: seed '{\"foo\":\"fooval6\"}' | cat -a test")
    assert [%{foo: "fooval5"},%{foo: "fooval6"}] = response
  end
end
