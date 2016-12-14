defmodule Cog.Test.Commands.Alias.MoveTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias

  alias Cog.Commands.Alias.Move
  import Cog.Support.ModelUtilities, only: [site_alias: 2,
                                            with_alias: 3,
                                            get_alias: 1,
                                            get_alias: 2,
                                            user: 1]

  setup :with_user

  describe "moving an alias to site" do
    setup :with_user_alias

    test "using full visibility syntax", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["user:my-new-alias", "site"])
      |> send_req(Move)

      assert(%{source: %{
                   name: "my-new-alias",
                   pipeline: "echo My New Alias",
                   visibility: "user"},
                destination: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "site"}} = response)

      command_alias = get_alias("my-new-alias")

      assert(command_alias.name == "my-new-alias")
    end

    test "using full visibility syntax and rename", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["user:my-new-alias", "site:my-renamed-alias"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "user"},
               destination: %{
                 name: "my-renamed-alias",
                 pipeline: "echo My New Alias",
                 visibility: "site"
               }} = response)

      assert(get_alias("my-renamed-alias"))
    end

    test "with short syntax", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "site"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "user"},
               destination: %{
                 name: "my-new-alias",
                 pipeline: "echo My New Alias",
                 visibility: "site"}} = response)

      assert(get_alias("my-new-alias"))
    end

    test "with short syntax and rename", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "site:my-renamed-alias"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "user"},
               destination: %{
                 name: "my-renamed-alias",
                 pipeline: "echo My New Alias",
                 visibility: "site"}} = response)

      assert(get_alias("my-renamed-alias"))
    end

    test "when an alias with that name already exists in site", %{user: user}do
      with_site_alias()

      {:error, error} = new_req(user: %{"id" => user.id}, args: ["user:my-new-alias", "site"])
      |> send_req(Move)

      assert(error == "name: The alias name is already in use.")
    end

  end

  describe "moving an alias to user" do
    setup :with_site_alias

    test "with full visibility syntax", %{user: user}  do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["site:my-new-alias", "user"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "site"},
               destination: %{
                 name: "my-new-alias",
                 pipeline: "echo My New Alias",
                 visibility: "user"}} = response)

      # Alias is not in the site namespace
      refute(get_alias("my-new-alias"))
      # Alias is in the user namespace
      assert(get_alias("my-new-alias", user.id))
    end

    test "with full visibility syntax and rename", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["site:my-new-alias", "user:my-renamed-alias"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "site"},
               destination: %{
                 name: "my-renamed-alias",
                 pipeline: "echo My New Alias",
                 visibility: "user"}} = response)

      refute(get_alias("my-new-alias"))
      assert(get_alias("my-renamed-alias", user.id))
    end

    test "with short syntax", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "user"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "site"},
               destination: %{
                 name: "my-new-alias",
                 pipeline: "echo My New Alias",
                 visibility: "user"}} = response)

      refute(get_alias("my-new-alias"))
      assert(get_alias("my-new-alias", user.id))
    end

    test "with short syntax and rename", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "user:my-renamed-alias"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "site"},
               destination: %{
                 name: "my-renamed-alias",
                 pipeline: "echo My New Alias",
                 visibility: "user"}} = response)

      refute(get_alias("my-renamed-alias"))
      assert(get_alias("my-renamed-alias", user.id))
    end

    test "when an alias with that name already exists in user", %{user: user}=context do
      with_user_alias(context)

      {:error, error} = new_req(user: %{"id" => user.id}, args: ["site:my-new-alias", "user"])
      |> send_req(Move)

      assert(error == "name: The alias name is already in use.")
    end

  end

  describe "renaming an alias" do
    test "renaming an alias in the user visibility", %{user: user}=context do
      with_user_alias(context)

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "my-renamed-alias"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "user"},
               destination: %{
                 name: "my-renamed-alias",
                 pipeline: "echo My New Alias",
                 visibility: "user"}} = response)

      refute(get_alias("my-new-alias", user.id))
      assert(get_alias("my-renamed-alias", user.id))
    end

    test "renaming an alias in the site visibility", %{user: user} do
      with_site_alias()

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["my-new-alias", "my-renamed-alias"])
      |> send_req(Move)

      assert(%{source: %{
                  name: "my-new-alias",
                  pipeline: "echo My New Alias",
                  visibility: "site"},
               destination: %{
                 name: "my-renamed-alias",
                 pipeline: "echo My New Alias",
                 visibility: "site"}} = response)

      refute(get_alias("my-new-alias"))
      assert(get_alias("my-renamed-alias"))
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

  # Site aliases don't require a user and so can be called with no args
  defp with_site_alias(context \\ %{})
  defp with_site_alias(_) do
    site_alias("my-new-alias", "echo My New Alias")
    :ok
  end
end
