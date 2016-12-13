defmodule Cog.Test.Commands.AliasTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias

  alias Cog.Commands.Alias.{Create, Move, Delete, List}
  import Cog.Support.ModelUtilities, only: [site_alias: 2,
                                            with_alias: 3,
                                            get_alias: 1,
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

  # Site aliases don't require a user and so can be called with no args
  defp with_site_alias(context \\ %{})
  defp with_site_alias(_) do
    site_alias("my-new-alias", "echo My New Alias")
    :ok
  end
end
