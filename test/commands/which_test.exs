defmodule Cog.Test.Commands.WhichTest do
  use Cog.CommandCase, command_module: Cog.Commands.Which

  import Cog.Support.ModelUtilities, only: [site_alias: 2,
                                            with_alias: 3,
                                            user: 1]

  setup :with_user

  test "an alias in the 'user' visibility", %{user: user}=context do
    with_user_alias(context)

    {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias"])
    |> send_req()

    assert(response == %{type: "alias",
                         scope: "user",
                         name: "my-new-alias",
                         pipeline: "echo My New Alias"})
  end

  test "an alias in the 'site' visibility", %{user: user} do
    with_site_alias()

    {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias"])
    |> send_req()

    assert(response == %{type: "alias",
                         scope: "site",
                         name: "my-new-alias",
                         pipeline: "echo My New Alias"})
  end

  test "a command", %{user: user} do
    {:ok, response} = new_req(user: %{"id" => user.id}, args: ["alias"])
    |> send_req()

    assert(response == %{type: "command",
                         scope: "operable",
                         name: "alias"})
  end

  test "an unknown", %{user: user} do
    {:ok, response} = new_req(user: %{"id" => user.id}, args: ["foo"])
    |> send_req()

    assert(response == %{not_found: true})
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

  # Site aliases don't require a user and so can be called with no args
  defp with_site_alias(context \\ %{})
  defp with_site_alias(_) do
    site_alias("my-new-alias", "echo My New Alias")
    :ok
  end
end
