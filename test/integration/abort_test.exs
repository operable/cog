defmodule Integration.AbortTest do

  use Cog.AdapterCase, provider: "test"

  @moduletag integration: :general
  @moduletag :command
  @moduletag :abort

  setup do
    user = user("vanstee", first_name: "Patrick", last_name: "Van Stee")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "abort-when aborts a pipeline", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": 1}]' | operable:abort-when $foo")
    assert String.starts_with?(response, "Command: operable:abort-when $foo\nCalling Environment: {\n  \"foo\": 1\n}\n")
    [response] = send_message(user, "@bot: operable:seed '[{\"foo\": 0}]' | operable:abort-when $foo")
    assert response == %{foo: 0}
  end

  test "abort-when uses custom abort message", %{user: user} do
    response = send_message(user, "@bot: operable:seed '[{\"foo\": 1}]' | operable:abort-when -m \"PIPELINE ABORT\" $foo")
    assert String.starts_with?(response, "Command: operable:abort-when -m \"PIPELINE ABORT\" $foo\nCalling Environment: {\n  \"foo\": 1\n}\n")
  end

  test "abort-when works in middle of pipeline", %{user: user} do
    json = Poison.encode!([%{foo: 0}, %{foo: 0}, %{foo: 1}, %{foo: 0}])
    response = send_message(user, "@bot: operable:seed '#{json}' | operable:abort-when $foo | operable:echo foo is $foo")
    assert String.starts_with?(response, "Command: operable:abort-when $foo\nCalling Environment: {\n  \"foo\": 1\n}\n")
  end

end
