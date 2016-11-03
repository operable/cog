defmodule Cog.Test.Commands.AliasTest do
  use Cog.CommandCase, command_module: Cog.Commands.Alias

  import Cog.Support.ModelUtilities, only: [site_alias: 2,
                                            with_alias: 3,
                                            get_alias: 1,
                                            get_alias: 2,
                                            user: 1]

  setup :with_user

  describe "alias creation" do
    test "with standard args", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["create", "my-new-alias", "echo My New Alias"])
      |> send_req()

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

      {:error, error} = new_req(user: %{"id" => user.id}, args: ["create", "my-new-alias", "echo My New Alias"])
      |> send_req()

      assert(error == "name: The alias name is already in use.")
    end
  end

  describe "alias removal" do
    setup :with_user_alias

    test "removing an alias", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["delete", "my-new-alias"])
      |> send_req()

      assert(%{name: "my-new-alias",
               pipeline: "echo My New Alias",
               visibility: "user"} = response)

      deleted_alias = get_alias("my-new-alias", user.id)

      refute deleted_alias
    end

    test "removing an alias that does not exist", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["delete", "my-non-existant-alias"])
      |> send_req()

      assert(error == "I can't find 'my-non-existant-alias'. Please try again")
    end
  end

  describe "moving an alias to site" do
    setup :with_user_alias

    test "using full visibility syntax", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "user:my-new-alias", "site"])
      |> send_req()

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
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "user:my-new-alias", "site:my-renamed-alias"])
      |> send_req()

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
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "my-new-alias", "site"])
      |> send_req()

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
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "my-new-alias", "site:my-renamed-alias"])
      |> send_req()

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

    test "when an alias with that name already exists in site", %{user: user}=context do
      with_site_alias(context)

      {:error, error} = new_req(user: %{"id" => user.id}, args: ["move", "user:my-new-alias", "site"])
      |> send_req()

      assert(error == "name: The alias name is already in use.")
    end

  end

  describe "moving an alias to user" do
    setup :with_site_alias

    test "with full visibility syntax", %{user: user}  do
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "site:my-new-alias", "user"])
      |> send_req()

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
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "site:my-new-alias", "user:my-renamed-alias"])
      |> send_req()

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
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "my-new-alias", "user"])
      |> send_req()

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
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "my-new-alias", "user:my-renamed-alias"])
      |> send_req()

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

      {:error, error} = new_req(user: %{"id" => user.id}, args: ["move", "site:my-new-alias", "user"])
      |> send_req()

      assert(error == "name: The alias name is already in use.")
    end

  end

  describe "renaming an alias" do
    test "renaming an alias in the user visibility", %{user: user}=context do
      with_user_alias(context)

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "my-new-alias", "my-renamed-alias"])
      |> send_req()

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

    test "renaming an alias in the site visibility", %{user: user}=context do
      with_site_alias(context)

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["move", "my-new-alias", "my-renamed-alias"])
      |> send_req()

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
    test "all", %{user: user}=context do
      Enum.each(1..3, &with_alias(user, "my-new-alias#{&1}", "echo My New Alias"))
      with_site_alias(context)

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["list"])
      |> send_req()

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

    test "matching a pattern", %{user: user}=context do
      Enum.each(1..2, &with_alias(user, "my-new-alias#{&1}", "echo My New Alias"))
      Enum.each(1..2, &with_alias(user, "new-alias#{&1}", "echo My New Alias"))
      with_site_alias(context)

      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["list", "my-*"])
      |> send_req()

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

    test "is the default action", %{user: user}=context do
      with_user_alias(context)

      {:ok, response} = new_req(user: %{"id" => user.id})
      |> send_req()

      assert([%{visibility: "user",
                pipeline: "echo My New Alias",
                name: "my-new-alias"}] == response)
    end

    test "with no matching pattern", %{user: user}=context do
      with_site_alias(context)
      {:ok, response} = new_req(user: %{"id" => user.id}, args: ["list", "their-*"])
      |> send_req()

      assert([] == response)
    end

    test "with no aliases", %{user: user} do
      {:ok, response} = new_req(user: %{"id" => user.id})
      |> send_req()

      assert([] == response)
    end

    test "with an invalid pattern", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["list", "% &my#-*"])
      |> send_req()

      assert(error == "Invalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _")
    end

    test "with too many wildcards", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["list", "*my-*"])
      |> send_req()

      assert(error == "Too many wildcards. You can only include one wildcard in a query")
    end

    test "with a bad pattern and too many wildcards", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["list", "*m++%y-*"])
      |> send_req()

      assert(error == "Too many wildcards. You can only include one wildcard in a query\nInvalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _")
    end
  end

  describe "alias args" do
    test "passing too many", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["create", "my-invalid-alias", "echo foo", "invalid-arg"])
      |> send_req()

      assert(error == "Too many args. Arguments required: exactly 2.")
    end

    test "passing too few", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["create", "my-invalid-alias"])
      |> send_req()

      assert(error == "Not enough args. Arguments required: exactly 2.")
    end

    test "passing an unknown subcommand", %{user: user} do
      {:error, error} = new_req(user: %{"id" => user.id}, args: ["foo"])
      |> send_req()

      assert(error == "Unknown subcommand 'foo'")
    end
  end


  ### Context Functions ###

  defp with_user(_),
    do: [user: user("alias_test_user")]

  defp with_user_alias(context) do
    with_alias(context[:user], "my-new-alias", "echo My New Alias")
    :ok
  end

  defp with_site_alias(_) do
    site_alias("my-new-alias", "echo My New Alias")
    :ok
  end
end
