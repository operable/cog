defmodule Cog.Test.Commands.Alias.CreateTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias

  alias Cog.Commands.Alias.Create
  import Cog.Support.ModelUtilities, only: [with_alias: 3,
                                            get_alias: 2,
                                            user: 1]

  setup :with_user

  describe "alias creation" do
    test "with standard args", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "echo My New Alias"])
      |> send_req(Create)

      assert(%{name: "my-new-alias",
               pipeline: "echo My New Alias",
               visibility: "user"} = response)

      created_alias = get_alias("my-new-alias", user.id)

      assert(%{name: "my-new-alias",
               pipeline: "echo My New Alias",
               visibility: "user"} = created_alias)
    end

    test "with an existing name", %{user: user}=context do
      with_user_alias(context)

      {:error, error} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "echo My New Alias"])
      |> send_req(Create)

      assert(error == "name: The alias name is already in use.")
    end
  end

  describe "alias args" do
    test "passing too many", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["my-invalid-alias", "echo foo", "invalid-arg"])
      |> send_req(Create)

      assert(error == "Too many args. Arguments required: exactly 2.")
    end

    test "passing too few", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["my-invalid-alias"])
      |> send_req(Create)

      assert(error == "Not enough args. Arguments required: exactly 2.")
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
