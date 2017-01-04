defmodule Cog.Test.Commands.Alias.InfoTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias.Info

  import Cog.Support.ModelUtilities,
    only: [site_alias: 2, with_alias: 3, user: 1]

  setup do
    {:ok, %{user: user("alias_test_user")}}
  end

  test "showing a user alias", %{user: user} do
    with_alias(user, "my-awesome-alias", "echo 'awesome!'")

    {:ok, response} = new_req(user: %{"id" => user.id}, args: ["user:my-awesome-alias"])
    |> send_req()

    assert(%{visibility: "user",
             pipeline: "echo 'awesome!'",
             name: "my-awesome-alias"} == response)
  end

  test "showing a site alias" do
    site_alias("my-site-alias", "echo 'site!'")

    {:ok, response} = new_req(args: ["site:my-site-alias"])
    |> send_req()

    assert(%{visibility: "site",
             pipeline: "echo 'site!'",
             name: "my-site-alias"} == response)
  end
end
