defmodule Cog.Test.Commands.Alias.DeleteTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias

  alias Cog.Commands.Alias.Delete
  import Cog.Support.ModelUtilities, only: [with_alias: 3,
                                            get_alias: 2,
                                            user: 1]

  setup :with_user

  describe "alias removal" do
    setup :with_user_alias

    test "removing an alias", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias"])
      |> send_req(Delete)

      assert(%{name: "my-new-alias",
               pipeline: "echo My New Alias",
               visibility: "user"} = response)

      deleted_alias = get_alias("my-new-alias", user.id)

      refute deleted_alias
    end

    test "removing an alias that does not exist", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["my-non-existant-alias"])
      |> send_req(Delete)

      assert(error == "I can't find 'my-non-existant-alias'. Please try again")
    end
  end

  ### Context Functions ###

  defp with_user(),
    do: user("alias_test_user")
  defp with_user(_),
    do: [user: with_user()]

  # User aliases requires a user, so it must be called with context
  defp with_user_alias(%{user: user}) do
    with_alias(user, "my-new-alias", "echo My New Alias")
    :ok
  end
end
