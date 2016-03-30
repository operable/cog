# This module defines a `use_cassette/1` macro for use inside tests which uses
# the test name as the name for the recorded file. This means you can only use
# one `use_cassette/1` call per test definition. Here's an example:
#
# defmodule Cog.Adapters.HipChat.APITest do
#   use ExUnit.Case, async: false
#   use Cog.VCR
#   alias Cog.Adapters.HipChat
#
#   test "looking up a room", %{config: config} do
#     use_cassette do
#       HipChat.API.start_link(config)
#       assert {:ok, %{id: 1, name: "general"}} = HipChat.API.lookup_room(name: "general")
#     end
#   end
# end

defmodule Cog.VCR do
  defmacro __using__([]) do
    quote do
      use ExVCR.Mock, options: [clear_mock: true]

      defmacro use_cassette(do: context) do
        test_name = Module.get_attribute(__MODULE__, :ex_unit_test_names)
        |> Map.to_list
        |> List.last
        |> elem(0)

        module = __CALLER__.module

        quote do
          use_cassette("#{unquote(module)}.#{unquote(test_name)}", match_requests_on: [:query, :request_body]) do
            unquote(context)
          end
        end
      end
    end
  end
end
