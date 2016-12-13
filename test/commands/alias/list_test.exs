defmodule Cog.Test.Commands.Alias.ListTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias

  alias Cog.Commands.Alias.List
  import Cog.Support.ModelUtilities, only: [site_alias: 2,
                                            with_alias: 3,
                                            user: 1]

  setup :with_user

  describe "listing aliases" do
    test "all", %{user: user} do
      Enum.each(1..3, &with_alias(user, "my-new-alias#{&1}", "echo My New Alias"))
      with_site_alias()

      {:ok, response} = new_req(user: %{"id" => user.id}, args: [])
      |> send_req(List)

      assert([%{visibility: "site",
                pipeline: "echo My New Alias",
                name: "my-new-alias"},
              %{visibility: "user",
                pipeline: "echo My New Alias",
                name: "my-new-alias1"},
              %{visibility: "user",
                pipeline: "echo My New Alias",
                name: "my-new-alias2"},
              %{visibility: "user",
                pipeline: "echo My New Alias",
                name: "my-new-alias3"}] == response)
    end

    test "matching a pattern", %{user: user} do
      Enum.each(1..2, &with_alias(user, "my-new-alias#{&1}", "echo My New Alias"))
      Enum.each(1..2, &with_alias(user, "new-alias#{&1}", "echo My New Alias"))
      with_site_alias()

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-*"])
      |> send_req(List)

      assert([%{visibility: "site",
                pipeline: "echo My New Alias",
                name: "my-new-alias"},
              %{visibility: "user",
                pipeline: "echo My New Alias",
                name: "my-new-alias1"},
              %{visibility: "user",
                pipeline: "echo My New Alias",
                name: "my-new-alias2"}] == response)
    end

    test "with no matching pattern", %{user: user} do
      with_site_alias()
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["their-*"])
      |> send_req(List)

      assert([] == response)
    end

    test "with no aliases", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id})
      |> send_req(List)

      assert([] == response)
    end

    test "with an invalid pattern", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["% &my#-*"])
      |> send_req(List)

      assert(error == "Invalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _")
    end

    test "with too many wildcards", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["*my-*"])
      |> send_req(List)

      assert(error == "Too many wildcards. You can only include one wildcard in a query")
    end

    test "with a bad pattern and too many wildcards", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["*m++%y-*"])
      |> send_req(List)

      assert(error == "Too many wildcards. You can only include one wildcard in a query\nInvalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _")
    end
  end

  ### Context Functions ###

  defp with_user(),
    do: user("alias_test_user")
  defp with_user(_),
    do: [user: with_user()]

  # Site aliases don't require a user and so can be called with no args
  defp with_site_alias(context \\ %{})
  defp with_site_alias(_) do
    site_alias("my-new-alias", "echo My New Alias")
    :ok
  end
end
