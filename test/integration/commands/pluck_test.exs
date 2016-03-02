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

  test "with a bad field name", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": { \"one\": 1}, \"bar\": { \"two\": 2}, \"baz\": { \"three\": 3}} ]' | pluck --fields=qux")
    assert response["data"]["response"] == "@lucky Whoops! An error occurred. \n* You entered a field that is not present in each instance.\n\n"
  end
end
