defmodule Integration.Commands.PluckTest do
  use Cog.AdapterCase, adapter: "test"

  setup do
    user = user("lucky", first_name: "Shamaus", last_name: "McLucky")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "with no field option", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}} ]' | pluck")
    assert response["data"]["response"] == "{\n  \"foo\": {\n    \"one\": 1\n  },\n  \"bar\": {\n    \"two\": 2\n  }\n}"
  end

  test "with a single field input option", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}, \"baz\": { \"three\": 3}} ]' | pluck --fields=foo")
    assert response["data"]["response"] == "{\n  \"foo\": {\n    \"one\": 1\n  }\n}"
  end

  test "with multiple field options", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}, \"baz\": { \"three\": 3}} ]' | pluck --fields=foo,baz")
    assert response["data"]["response"] == "{\n  \"foo\": {\n    \"one\": 1\n  },\n  \"baz\": {\n    \"three\": 3\n  }\n}"
  end

  test "with a single field multiple lines", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}, \"baz\": { \"three\": 3}}, {\"foo\": { \"four\": 4}, \"bar\": { \"five\": 5}, \"baz\": { \"six\": 6}} ]' | pluck --fields=foo")
    assert response["data"]["response"] == "{\n  \"foo\": {\n    \"one\": 1\n  }\n}\n{\n  \"foo\": {\n    \"four\": 4\n  }\n}"
  end

  test "traversing the field to pluck specific data", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\":{\"bar\":{\"baz\":\"stuff\"}}, \"qux\": \"one\"}, {\"foo\": {\"bar\":{\"baz\":\"me\"}}, \"qux\": \"two\"}]' | pluck --fields=\"foo.bar\"")
    assert response["data"]["response"] == "{\n  \"foo.bar\": {\n    \"baz\": \"stuff\"\n  }\n}\n{\n  \"foo.bar\": {\n    \"baz\": \"me\"\n  }\n}"
  end

  test "traversing multiple fields to pluck specific data", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\":{\"bar\":{\"baz\":\"stuff\"}}, \"qux\": \"one\"}, {\"foo\": {\"bar\":{\"baz\":\"me\"}}, \"qux\": \"two\"}]' | pluck --fields=\"\"foo.bar\",qux\"")
    assert response["data"]["response"] == "{\n  \"qux\": \"one\",\n  \"foo\": {\n    \"bar\": {\n      \"baz\": \"stuff\"\n    }\n  }\n}\n{\n  \"qux\": \"two\",\n  \"foo\": {\n    \"bar\": {\n      \"baz\": \"me\"\n    }\n  }\n}"
  end

  test "with a bad field name", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}, \"baz\": { \"three\": 3}} ]' | pluck --fields=qux")
    assert response["data"]["response"] == "@lucky Whoops! An error occurred. \n* You entered a field that is not present in each instance: [[\"qux\"]]\n\n"
  end

  test "with a non-string field value", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}, \"true\": { \"three\": 3}} ]' | pluck --fields=true")
    assert response["data"]["response"] == "@lucky Whoops! An error occurred. \n* You entered a field that is ambiguous. Please quote the following in the field option: true\n\n"
  end
end
