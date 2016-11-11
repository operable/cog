defmodule Cog.Command.CommandResolver.Test do
  use Cog.ModelCase

  alias Cog.Command.CommandResolver
  alias Cog.Command.Pipeline.ParserMeta
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias

  test "an already-namespaced command is resolved as itself" do
    user = user("testuser")

    assert_command("operable", "echo",
                   CommandResolver.lookup("operable", "echo", user, enabled_bundles))
  end

  test "an already-namespaced user-alias is resolved as itself" do
    user = user("testuser")
    |> with_alias("my-alias", "echo 'this is my alias'")

    assert_user_alias(user,
                      "echo 'this is my alias'",
                      CommandResolver.lookup("user", "my-alias", user, enabled_bundles))
  end

  test "an already-namespaced site-alias is resolved as itself" do
    user = user("testuser")
    site_alias("my-site-alias", "echo 'this is a site alias'")

    assert_site_alias("echo 'this is a site alias'",
                      CommandResolver.lookup("site", "my-site-alias", user, enabled_bundles))
  end

  test "a user alias is preferred over a site alias or command of the same name" do
    alias_name = "echo"
    user = user("testuser")
    |> with_alias(alias_name, "echo 'user alias'")

    site_alias(alias_name, "echo 'site alias'")

    assert_user_alias(user,
                      "echo 'user alias'",
                      CommandResolver.lookup(nil, alias_name, user, enabled_bundles))
  end

  test "a site alias is preferred over a command of the same name (in absence of a user alias)" do
    alias_name = "echo"
    user = user("testuser")
    site_alias(alias_name, "echo 'site alias'")

    assert_site_alias("echo 'site alias'",
                      CommandResolver.lookup(nil, alias_name, user, enabled_bundles))
  end

  test "a command is preferred when no aliases of the same name are present" do
    user = user("testuser")

    assert_command("operable", "echo",
                   CommandResolver.lookup(nil, "echo", user, enabled_bundles))
  end

  test "user aliases are not shared" do
    user_with_alias = user("with-alias")
    |> with_alias("echo", "echo 'from user with alias'")

    user_without_alias = user("without-alias")

    assert_user_alias(user_with_alias,
                      "echo 'from user with alias'",
                      CommandResolver.lookup(nil, "echo", user_with_alias, enabled_bundles))

    assert_command("operable", "echo",
                   CommandResolver.lookup(nil, "echo", user_without_alias, enabled_bundles))
  end

  test "user aliases are distinct across users, even with the same name" do
    alias_name = "my-alias"
    user1 = user("user1")
    |> with_alias(alias_name, "echo 'hello from user1'")

    user2 = user("user2")
    |> with_alias(alias_name, "echo 'hello from user2, who clearly writes better aliases'")

    assert_user_alias(user1,
                      "echo 'hello from user1'",
                      CommandResolver.lookup(nil, alias_name, user1, enabled_bundles))

    assert_user_alias(user2,
                      "echo 'hello from user2, who clearly writes better aliases'",
                      CommandResolver.lookup(nil, alias_name, user2, enabled_bundles))
  end

  test "site aliases are shared" do
    alias_name = "echo"
    user1 = user("one")
    user2 = user("two")
    site_alias(alias_name, "echo 'from site'")

    assert_site_alias("echo 'from site'",
                      CommandResolver.lookup(nil, alias_name, user1, enabled_bundles))

    assert_site_alias("echo 'from site'",
                      CommandResolver.lookup(nil, alias_name, user2, enabled_bundles))
  end

  test "a command in more than one bundle is ambiguous absent any explicit qualification" do
    # Create a new bundle with an "echo" command to be ambiguous with
    # the embedded "operable:echo" command
    config = %{
      "name" => "test_bundle",
      "version" => "0.0.1",
      "commands" => %{
        "echo" => %{
          "module" => "Cog.Commands.Echo",
          "documentation" => "does stuff"}}}
    Cog.Repository.Bundles.install(%{"name" => "test_bundle",
                                     "version" => "0.0.1",
                                     "config_file" => config})
    user = user("testuser")

    result = CommandResolver.lookup(nil, "echo", user, enabled_bundles)
    assert result == {:ambiguous, ["operable", "test_bundle"]}
  end

  test "no aliases and no command mean nothing is found!" do
    user = user("testuser")
    result = CommandResolver.lookup(nil, "there_is_nothing_named_this", user, enabled_bundles)
    assert result == :not_found
  end


  test "appropriately versioned rules and site rules are returned in the parser metadata" do
    user = user("test-user")
    permission("site:all_the_things")

    v1_rule   = "when command is testing:hello must have testing:foo"
    v2_rule   = "when command is testing:hello must have testing:bar"
    site_rule = "when command is testing:hello must have site:all_the_things"

    # Create two versions of a bundle, with different rules for a
    # single command
    {:ok, version1} = Cog.Repository.Bundles.install(
      %{"name" => "testing",
        "version" => "1.0.0",
        "config_file" => %{"name" => "testing",
                           "version" => "1.0.0",
                           "permissions" => ["testing:foo"],
                           "commands" => %{"hello" => %{"rules" => [v1_rule]}}}})
    {:ok, version2} = Cog.Repository.Bundles.install(
      %{"name" => "testing",
        "version" => "2.0.0",
        "config_file" => %{"name" => "testing",
                           "version" => "2.0.0",
                           "permissions" => ["testing:bar"],
                           "commands" => %{"hello" => %{"rules" => [v2_rule]}}}})

    # Add a site rule for that same command
    rule(site_rule)

    # Enable the first version and verify that the right bundle rule
    # AND the site rule come back
    :ok = Cog.Repository.Bundles.set_bundle_version_status(version1, :enabled)

    parser_meta = CommandResolver.lookup("testing", "hello", user, enabled_bundles)

    version1_version = version1.version
    version1_id = version1.id
    assert %ParserMeta{bundle_name: "testing",
                       command_name: "hello",
                       version: ^version1_version,
                       bundle_version_id: ^version1_id,
                       options: [],
                       rules: _} = parser_meta

    # We got the right rules back
    assert [site_rule, v1_rule] == rules_to_text(parser_meta.rules)

    # Now, enable the OTHER version and verify that the SECOND rule comes
    # back along with the SAME site rule
    :ok = Cog.Repository.Bundles.set_bundle_version_status(version2, :enabled)

    parser_meta = CommandResolver.lookup("testing", "hello", user, enabled_bundles)

    version2_version = version2.version
    version2_id = version2.id
    assert %ParserMeta{bundle_name: "testing",
                       command_name: "hello",
                       version: ^version2_version,
                       bundle_version_id: ^version2_id,
                       options: [],
                       rules: _} = parser_meta

    # We get the rule from version 2, as well as our site rule
    assert [site_rule, v2_rule] == rules_to_text(parser_meta.rules)

    # Let's also just double-check that disabled rules don't show up,
    # either; we'll "delete" the bundle rule, leaving only the site rule
    [rule_to_delete] = Cog.Repo.preload(version2, [rules: :bundle_versions]).rules
    Cog.Repository.Rules.delete_or_disable(rule_to_delete)

    # Retrieve the rules again; we should only get the site one
    %ParserMeta{rules: rules} = CommandResolver.lookup("testing", "hello", user, enabled_bundles)
    assert [site_rule] == rules_to_text(rules)

    # And the rule we "deleted" really is disabled
    assert %Cog.Models.Rule{enabled: false} = Cog.Repo.get(Cog.Models.Rule, rule_to_delete.id)

  end

  ########################################################################

  # Convenience function to take a list of Rule models and turn them
  # back into plain rule text
  defp rules_to_text(rules) do
    rules
    |> Enum.map(&(Piper.Permissions.Parser.json_to_rule!(&1.parse_tree)))
    |> Enum.map(&to_string/1)
    |> Enum.sort
  end

  defp enabled_bundles do
    Cog.Repository.Bundles.enabled_bundles
  end

  defp assert_command(bundle, name, actual) do
    assert match?(%ParserMeta{}, actual)
    assert actual.command_name == name
    assert actual.bundle_name == bundle
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
