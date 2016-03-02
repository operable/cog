defmodule Cog.Command.CommandResolver.Test do
  use Cog.ModelCase

  alias Cog.Command.CommandResolver
  alias Cog.Models.Command
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Repo

  test "an already-namespaced command is resolved as itself" do
    user = user("testuser")

    assert_command("operable", "echo",
                   CommandResolver.lookup("operable", "echo", user))
  end

  test "an already-namespaced user-alias is resolved as itself" do
    user = user("testuser")
    |> with_alias("my-alias", "echo 'this is my alias'")

    assert_user_alias(user,
                      "echo 'this is my alias'",
                      CommandResolver.lookup("user", "my-alias", user))
  end

  test "an already-namespaced site-alias is resolved as itself" do
    user = user("testuser")
    site_alias("my-site-alias", "echo 'this is a site alias'")

    assert_site_alias("echo 'this is a site alias'",
                      CommandResolver.lookup("site", "my-site-alias", user))
  end

  test "a user alias is preferred over a site alias or command of the same name" do
    alias_name = "echo"
    user = user("testuser")
    |> with_alias(alias_name, "echo 'user alias'")

    site_alias(alias_name, "echo 'site alias'")

    assert_user_alias(user,
                      "echo 'user alias'",
                      CommandResolver.lookup(nil, alias_name, user))
  end

  test "a site alias is preferred over a command of the same name (in absence of a user alias)" do
    alias_name = "echo"
    user = user("testuser")
    site_alias(alias_name, "echo 'site alias'")

    assert_site_alias("echo 'site alias'",
                      CommandResolver.lookup(nil, alias_name, user))
  end

  test "a command is preferred when no aliases of the same name are present" do
    user = user("testuser")

    assert_command("operable", "echo",
                   CommandResolver.lookup(nil, "echo", user))
  end

  test "user aliases are not shared" do
    user_with_alias = user("with-alias")
    |> with_alias("echo", "echo 'from user with alias'")

    user_without_alias = user("without-alias")

    assert_user_alias(user_with_alias,
                      "echo 'from user with alias'",
                      CommandResolver.lookup(nil, "echo", user_with_alias))

    assert_command("operable", "echo",
                   CommandResolver.lookup(nil, "echo", user_without_alias))
  end

  test "user aliases are distinct across users, even with the same name" do
    alias_name = "my-alias"
    user1 = user("user1")
    |> with_alias(alias_name, "echo 'hello from user1'")

    user2 = user("user2")
    |> with_alias(alias_name, "echo 'hello from user2, who clearly writes better aliases'")

    assert_user_alias(user1,
                      "echo 'hello from user1'",
                      CommandResolver.lookup(nil, alias_name, user1))

    assert_user_alias(user2,
                      "echo 'hello from user2, who clearly writes better aliases'",
                      CommandResolver.lookup(nil, alias_name, user2))
  end

  test "site aliases are shared" do
    alias_name = "echo"
    user1 = user("one")
    user2 = user("two")
    site_alias(alias_name, "echo 'from site'")

    assert_site_alias("echo 'from site'",
                      CommandResolver.lookup(nil, alias_name, user1))

    assert_site_alias("echo 'from site'",
                      CommandResolver.lookup(nil, alias_name, user2))
  end

  test "a command in more than one bundle is ambiguous absent any explicit qualification" do
    # Create a new bundle with an "echo" command to be ambiguous with
    # the embedded "operable:echo" command
    config = %{
      "bundle" => %{"name" => "test_bundle"},
      "templates" => [],
      "rules" => [],
      "permissions" => [],
      "commands" => [%{"version" => "0.0.1",
                       "options" => [],
                       "name" => "echo",
                       "module" => "Cog.Commands.Echo",
                       "execution" => "multiple",
                       "enforcing" => false,
                       "documentation" => "does stuff",
                       "calling_convention" => "bound"}]}
    Cog.Bundle.Install.install_bundle(%{name: "test_bundle",
                                        config_file: config,
                                        manifest_file: %{}})
    user = user("testuser")

    result = CommandResolver.lookup(nil, "echo", user)
    assert result == {:ambiguous, ["operable", "test_bundle"]}
  end

  test "no aliases and no command mean nothing is found!" do
    user = user("testuser")
    result = CommandResolver.lookup(nil, "there_is_nothing_named_this", user)
    assert result == :not_found
  end

  ########################################################################

  # Returns user for use in pipelines
  defp with_alias(user, name, pipeline_text) do
    %UserCommandAlias{}
    |> UserCommandAlias.changeset(%{name: name,
                                    pipeline: pipeline_text,
                                    user_id: user.id})
    |> Repo.insert!

    user
  end

  defp site_alias(name, pipeline_text) do
    %SiteCommandAlias{}
    |> SiteCommandAlias.changeset(%{name: name,
                                    pipeline: pipeline_text})
    |> Repo.insert!
  end

  defp assert_command(bundle, name, actual) do
    assert match?(%Command{}, actual)
    assert actual.name == name
    refute match?(%Ecto.Association.NotLoaded{}, actual.bundle), "Bundle should be preloaded"
    assert actual.bundle.name == bundle
    refute match?(%Ecto.Association.NotLoaded{}, actual.rules), "Rules should be preloaded"
    refute match?(%Ecto.Association.NotLoaded{}, actual.options), "Options should be preloaded"
  end

  defp assert_user_alias(user, expected_pipeline, actual) do
    assert actual.__struct__ == UserCommandAlias
    assert match?(%UserCommandAlias{}, actual)
    assert actual.pipeline == expected_pipeline
    assert actual.user_id == user.id
  end

  defp assert_site_alias(expected_pipeline, actual) do
    assert match?(%SiteCommandAlias{}, actual)
    assert actual.pipeline == expected_pipeline
  end
end
