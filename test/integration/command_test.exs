defmodule Integration.CommandTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "running a command with a required option", %{user: user} do
    response = send_message(user, "@bot: operable:req-opt --req=\"foo\"")

    assert response == "req-opt response"
  end

  test "running a command with a required option missing", %{user: user} do
    response = send_message(user, "@bot: operable:req-opt")

    assert_error_message_contains(response, "Whoops! An error occurred. Looks like you forgot to include some required options: 'req'")
  end

  test "running a command with a 'string' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --string=\"a string\"")

    assert response == "type-test response"
  end

  test "running a command with a 'bool' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --bool=true")
    assert response == "type-test response"

    response = send_message(user, "@bot: operable:type-test --bool=t")
    assert response == "type-test response"

    response = send_message(user, "@bot: operable:type-test --bool=1")
    assert response == "type-test response"

    response = send_message(user, "@bot: operable:type-test --bool=y")
    assert response == "type-test response"

    response = send_message(user, "@bot: operable:type-test --bool=yes")
    assert response == "type-test response"

    response = send_message(user, "@bot: operable:type-test --bool=on")
    assert response == "type-test response"

    response = send_message(user, "@bot: operable:type-test --bool")
    assert response == "type-test response"
  end

  test "running a command with an 'int' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --int=1")

    assert response == "type-test response"
  end

  test "running a command with an invalid 'int' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --int=\"this is a string\"")

    assert_error_message_contains(response, "Whoops! An error occurred. Type Error: `\"this is a string\"` is not of type `int`")
  end

  test "running a command with a 'float' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --float=1.0")

    assert response == "type-test response"
  end

  test "running a command with an invalid 'float' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --float=\"This is a string\"")

    assert_error_message_contains(response, "Whoops! An error occurred. Type Error: `\"This is a string\"` is not of type `float`")
  end

  test "running a command with an 'incr' option", %{user: user} do
    response = send_message(user, "@bot: operable:type-test --incr")

    assert response == "type-test response"
  end

  test "running the st-echo command with permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    response = send_message(user, "@bot: operable:st-echo test")
    assert response == "test"
  end

  test "running the st-echo command without permission", %{user: user} do
    response = send_message(user, "@bot: operable:st-echo test")

    assert_error_message_contains(response, "You will need at least one of the following permissions to run this command: 'operable:st-echo'.")
  end

  test "running the un-enforced t-echo command without permission", %{user: user} do
    response = send_message(user, "@bot: operable:t-echo test")

    assert response == "test"
  end

  test "running commands in a pipeline", %{user: user} do
    user
    |> with_permission("operable:t-echo")
    |> with_permission("operable:st-thorn")

    response = send_message(user, ~s(@bot: operable:t-echo "this is a test" | operable:st-thorn $body[0]))

    assert response == "þis is a test"
  end

  test "running commands in a pipeline without permission", %{user: user} do
    user |> with_permission("operable:st-echo")

    response = send_message(user, ~s(@bot: operable:st-echo "this is a test" | operable:st-thorn $body))

    assert_error_message_contains(response, "You will need at least one of the following permissions to run this command: 'operable:st-thorn'.")
  end

  test "running unknown commands", %{user: user} do
    response = send_message(user, "@bot: operable:weirdo test")

    assert_error_message_contains(response, "Command 'weirdo' not found in any installed bundle.")
  end

  test "running a command in a pipeline with nil output", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"a": "1", "b": "2"}, {"a": "3"}]' | filter --path=b | echo $a))

    assert response == 1
  end

  test "running a pipeline with a variable that resolves to a command fails with a parse error", %{user: user} do
    response = send_message(user, ~s(@bot: echo "echo" | $body[0] foo))

    assert_error_message_contains(response, "(Line: 1, Col: 15) syntax error before: \"body\".")
  end

  test "reading the path to filter a certain path", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"foo":{"bar":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | operable:filter --path="foo.bar"))

    assert response == [%{foo: %{bar: %{baz: "stuff"}}},
                        %{foo: %{bar: %{baz: "me"}}}]
  end

  test "reading the path to allow quoted path if supplied", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"foo":{"bar.qux":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | operable:filter --path='foo."bar.qux".baz'))

    assert response == [%{foo: %{"bar.qux": %{baz: "stuff"}}}]
  end

  test "returning the path that contains the matching value", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"foo":{"bar":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | operable:filter --path="foo.bar.baz" --matches=me))

    assert response == [%{foo: %{bar: %{baz: "me"}}}]
  end

  test "returning an error if matches is not a valid string", %{user: user} do
    response = send_message(user, ~s(@bot: seed '{"foo":{"bar":{"baz":"stuff"}}}' | operable:filter --path="foo.bar.baz" --matches="st[uff"))

    assert_error_message_contains(response, "Whoops! An error occurred. \n* The regular expression in '--matches' does not compile correctly.")
  end

  test "returning an error if matches is used without a path", %{user: user} do
    response = send_message(user, ~s(@bot: seed '{"foo":{"bar":{"baz":"stuff"}}}' | operable:filter --matches="stuff"))

    assert_error_message_contains(response, "Whoops! An error occurred. \n* Must specify '--path' with the '--matches' option.")
  end

  test "an empty response from the filter command single input item", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{ "foo": { "one": { "name": "asdf" }, "two": { "name": "fdsa" } } }]' | operable:filter --path="foo.one.name" --matches="/blurp/"))

    assert "Pipeline executed successfully, but no output was returned" = response
  end

  test "filter matching using regular expression", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[ {"key": "Name", "value": "test1"}, {"key": "Name", "value": "test2"} ]' | operable:filter --path="value" --matches="test[0-9]"))

    assert response == [%{key: "Name", value: "test1"}, %{key: "Name", value: "test2"}]
  end

  test "filter where the path has no matching value but the matches value is in the input list", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[ {"key": "Name", "value": "test1"}, {"key": "Name", "value": "test2"} ]' | operable:filter --path="value" --matches="Name"))

    assert "Pipeline executed successfully, but no output was returned" = response
  end

  test "filter where execution further down the pipeline only executes how many times the output is generated from the filter command", %{user: user} do
    response = send_message(user, ~s(@bot: seed '[{"key": "foo"}, {"key": "bar"}, {"key": "baz"}]' | operable:filter --path "key" --matches "bar" | operable:echo "do-something-dangerous --option=" $key))

    assert response == "do-something-dangerous --option= bar"
  end
end
