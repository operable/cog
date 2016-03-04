defmodule Integration.Commands.PluckTest do
  use Cog.AdapterCase, adapter: "test"
  alias Cog.Integration.Helpers

  setup do
    user = user("lucky", first_name: "Shamaus", last_name: "McLucky")
    |> with_chat_handle_for("test")

    {:ok, %{user: user}}
  end

  test "with no field option", %{user: user} do
    input = [%{foo: %{one: 1}, bar: %{two: 2}}]
    response = send_message(user, Helpers.seed(input, "pluck"))
    output = Helpers.unmangle_multiple_output(response["data"]["response"])
    assert output == input
  end

  test "with a single field input option", %{user: user} do
    input = [%{foo: %{one: 1},
               bar: %{two: 2},
               baz: %{three: 3}}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=foo"))
    output = Helpers.unmangle_multiple_output(response["data"]["response"])
    assert output == [%{foo: %{one: 1}}]
  end

  test "with multiple field options", %{user: user} do
    input = [%{foo: %{one: 1},
               bar: %{two: 2},
               baz: %{three: 3}}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=foo,baz"))
    output = Helpers.unmangle_multiple_output(response["data"]["response"])
    assert output == [%{foo: %{one: 1},
                        baz: %{three: 3}}]
  end

  test "with a single field multiple lines", %{user: user} do
    input = [%{foo: %{one: 1},
               bar: %{two: 2},
               baz: %{three: 3}},
             %{foo: %{four: 4},
               bar: %{five: 5},
               baz: %{six: 6}} ]
    response = send_message(user, Helpers.seed(input, "pluck --fields=foo"))
    output = Helpers.unmangle_multiple_output(response["data"]["response"])
    assert output == [%{foo: %{one: 1}},
                      %{foo: %{four: 4}}]
  end

  test "traversing the field to pluck specific data", %{user: user} do
    input = [%{foo: %{bar: %{baz: "stuff"}},
               qux: "one"},
             %{foo: %{bar: %{baz: "me"}},
               qux: "two"}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=\"foo.bar\""))
    output = Helpers.unmangle_multiple_output(response["data"]["response"])
    assert output == [%{"foo.bar": %{baz: "stuff"}},
                      %{"foo.bar": %{baz: "me"}}]
  end

  test "traversing multiple fields to pluck specific data", %{user: user} do
    input = [%{foo: %{bar: %{baz: "stuff"}},
               qux: "one"},
             %{foo: %{bar: %{baz: "me"}},
               qux: "two"}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=\"'foo.bar',qux\""))
    output = Helpers.unmangle_multiple_output(response["data"]["response"])
    assert output == [%{"foo.bar": %{baz: "stuff"},
                        qux: "one"},
                      %{"foo.bar": %{baz: "me"},
                        qux: "two"}]
  end

  test "with a bad field name", %{user: user} do
    input = [%{foo: %{bar: %{baz: "stuff"}}},
             %{foo: %{bar: %{baz: "me"}}}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=qux"))
    assert response["data"]["response"] == "@lucky Whoops! An error occurred. \n* You entered a field that is not present in each instance: [\"qux\"]\n\n"
  end


  test "with a multiple bad field names", %{user: user} do
    input = [%{foo: %{bar: %{baz: "stuff"}},
               qux: "one"},
             %{foo: %{bar: %{baz: "me"}},
               qux: "two"}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=\"'foo.bar.ba',qu\""))
    assert response["data"]["response"] == "@lucky Whoops! An error occurred. \n* You entered a field that is not present in each instance: [\"foo.bar.ba\", \"qu\"]\n\n"
  end

  test "with a non-string field value", %{user: user} do
    input = [%{"foo" => %{"bar" => %{"baz" => "stuff"}},
               "true" => "one"},
             %{"foo" => %{"bar" => %{"baz" => "me"}},
               "true" => "two"}]
    response = send_message(user, Helpers.seed(input, "pluck --fields=true"))
    assert response["data"]["response"] == "@lucky Whoops! An error occurred. \n* You entered an ambiguous field. Please quote the following in the field option: true\n\n"
  end
end
