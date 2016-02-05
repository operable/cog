defmodule Integration.CommandTest do
  use Cog.AdapterCase, adapter: Cog.Adapters.Test

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "running a command with a required option", %{user: user} do
    send_message user, "@bot: operable:req-opt --req=\"foo\""
    assert_response "req-opt response"
  end

  test "running a command with a required option missing", %{user: user} do
    send_message user, "@bot: operable:req-opt"
    assert_response "@vanstee Whoops! An error occurred. Looks like you forgot to include some required options: 'req'"
  end

  test "running a command with a 'string' option", %{user: user} do
    send_message user, "@bot: operable:type-test --string=\"a string\""
    assert_response "type-test response"
  end

  test "running a command with a 'bool' option", %{user: user} do
    send_message user, "@bot: operable:type-test --bool=true"
    assert_response "type-test response"

    send_message user, "@bot: operable:type-test --bool=t"
    assert_response "type-test response"

    send_message user, "@bot: operable:type-test --bool=1"
    assert_response "type-test response"

    send_message user, "@bot: operable:type-test --bool=y"
    assert_response "type-test response"

    send_message user, "@bot: operable:type-test --bool=yes"
    assert_response "type-test response"

    send_message user, "@bot: operable:type-test --bool=on"
    assert_response "type-test response"

    send_message user, "@bot: operable:type-test --bool"
    assert_response "type-test response"
  end

  test "running a command with an 'int' option", %{user: user} do
    send_message user, "@bot: operable:type-test --int=1"
    assert_response "type-test response"
  end

  test "running a command with an invalid 'int' option", %{user: user} do
    send_message user, "@bot: operable:type-test --int=\"this is a string\""
    assert_response "@vanstee Whoops! An error occurred. Type Error: 'this is a string' is not of type 'int'"
  end

  test "running a command with a 'float' option", %{user: user} do
    send_message user, "@bot: operable:type-test --float=1.0"
    assert_response "type-test response"
  end

  test "running a command with an invalid 'float' option", %{user: user} do
    send_message user, "@bot: operable:type-test --float=\"This is a string\""
    assert_response "@vanstee Whoops! An error occurred. Type Error: 'This is a string' is not of type 'float'"
  end

  test "running a command with an 'incr' option", %{user: user} do
    send_message user, "@bot: operable:type-test --incr"
    assert_response "type-test response"
  end

  test "running the st-echo command with permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    send_message user, "@bot: operable:st-echo test"
    assert_response "test"
  end

  test "running the st-echo command without permission", %{user: user} do
    send_message user, "@bot: operable:st-echo test"
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-echo test' :(\n You will need the 'operable:st-echo' permission to run this command."
  end

  test "running the un-enforced t-echo command without permission", %{user: user} do
    send_message user, "@bot: operable:t-echo test"
    assert_response "test"
  end

  test "running commands in a pipeline", %{user: user} do
    user
    |> with_permission("operable:echo")
    |> with_permission("operable:thorn")

    send_message user, ~s(@bot: operable:echo "this is a test" | operable:thorn $body)
    assert_response "þis is a test"
  end

  test "running commands in a pipeline without permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    send_message user, ~s(@bot: operable:st-echo "this is a test" | operable:st-thorn $body)
    assert_response "@vanstee Sorry, you aren't allowed to execute 'operable:st-thorn $body' :(\n You will need the 'operable:st-thorn' permission to run this command."
  end

  test "running unknown commands", %{user: user} do
    send_message user, "@bot: operable:weirdo test"
    assert_response "@vanstee Sorry, I don't know the 'operable:weirdo' command :("
  end
end
