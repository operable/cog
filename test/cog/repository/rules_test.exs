defmodule Cog.Repository.RulesTest do
  use Cog.ModelCase
  alias Cog.Models.{Rule, Bundle, Command}
  alias Cog.Repository.{Rules, Bundles}
  alias Piper.Permissions.Parser

  setup do
    bundle = %Bundle{}
    |> Bundle.changeset(%{name: "s3"})
    |> Repo.insert!

    command = %Command{}
    |> Command.changeset(%{name: "put", bundle_id: bundle.id})
    |> Repo.insert!

    permission = permission("s3:delete")

    {:ok, bundle: bundle, command: command, permission: permission}
  end

  test "a valid rule gets parsed and saved" do
    rule_text = "when command is s3:put with option[op] == 'replace' must have s3:delete"
    expr = Parser.rule_to_json!(expr(rule_text))

    assert {:ok, %Rule{parse_tree: ^expr}} = Rules.ingest(rule_text)
  end

  test "invalid rules are not ingested and return a syntax error message" do
    actual = Rules.ingest("monkeys monkeys monkeys")
    expected = {:error, {:invalid_rule_syntax, "(Line: 1, Col: 0) syntax error before: \"monkeys\"."}}
    assert ^expected = actual
  end

  test "rules referencing permissions from a different bundle return an error" do
    permission("aws:write")

    rule_text = "when command is s3:put must have aws:write"

    assert {:error, {:permission_bundle_mismatch, "aws:write"}} = Rules.ingest(rule_text)
  end

  test "a rule for an unrecognized command is not inserted" do
    rule_text = "when command is s3:monkeys with option[op] == 'replace' must have s3:delete"

    actual = Rules.ingest(rule_text)
    assert({:error, {:unrecognized_command, "s3:monkeys"}} = actual)
  end

  test "ingesting a rule you've already ingested returns the exact same rule that was inserted earlier" do
    rule_text = "when command is s3:put with option[op] == 'replace' must have s3:delete"

    {:ok, %Rule{id: id}} = Rules.ingest(rule_text)
    assert {:ok, %Rule{id: ^id}} = Rules.ingest(rule_text)
  end

  test "a rule is linked by database references to the required permissions", %{permission: permission} do
    rule_text = "when command is s3:put with option[op] == 'replace' must have s3:delete"
    site = Bundles.site_bundle_version

    rule = rule_text
    |> rule(site)
    |> Repo.preload(:permissions)

    assert [^permission] = rule.permissions
  end

  test "if multiple permissions are required, all are linked" do
    permissions = ["s3:delete", "s3:admin", "site:ops"]
    |> Enum.map(&permission/1)
    |> Enum.sort

    rule_text = """
    when command is s3:put
    with option[op] == 'replace'
    must have s3:delete or
              s3:admin or
              site:ops
    """
    rule = rule(rule_text) |> Repo.preload(:permissions)
    retrieved_permissions = rule.permissions |> Enum.sort

    assert ^permissions = retrieved_permissions
  end

  test "all permissions must be present in the database to ingest a rule" do
    rule_text = "when command is s3:put with option[op] == 'replace' must have s3:deletez"

    assert {:error, {:unrecognized_permission, "s3:deletez"}} = Rules.ingest(rule_text)
  end

  test "a parse tree can round-trip to and from the database", %{command: command} do
    inserted_rule = rule("when command is s3:put with option[op] == 'replace' must have s3:delete")

    %Rule{parse_tree: retrieved_tree} = Repo.one!(Ecto.assoc(command, :rules))
    assert ^retrieved_tree = inserted_rule.parse_tree
  end

  test "deleting a bundle rule actually disables it" do
    rule_text = "when command is foo:bar allow"
    {:ok, version} = Cog.Repository.Bundles.install(
      %{"name" => "foo",
        "version" => "1.0.0",
        "config_file" => %{
          "name" => "foo",
          "version" => "1.0.0",
          "commands" => %{"bar" => %{"rules" => [rule_text]}}}})

    [rule] = Cog.Repo.preload(version, [rules: :bundle_versions]).rules

    assert rule.enabled

    Cog.Repository.Rules.delete_or_disable(rule)

    %Rule{}=rule = Cog.Repository.Rules.rule(rule.id)

    refute rule.enabled
  end

  test "deleting a site bundle rule actually deletes it" do
    permission("site:testing")

    {:ok, version} = Cog.Repository.Bundles.install(
      %{"name" => "foo",
        "version" => "1.0.0",
        "config_file" => %{
          "name" => "foo",
          "version" => "1.0.0",
          "commands" => %{"bar" => %{"rules" => ["when command is foo:bar allow"]}}}})

    {:ok, rule} = Cog.Repository.Rules.ingest("when command is foo:bar must have site:testing",
                                              Cog.Repository.Bundles.site_bundle_version)

    assert rule.enabled

    Cog.Repository.Rules.delete_or_disable(rule)

    refute Cog.Repository.Rules.rule(rule.id)
  end

  test "Creating a site bundle rule that's the same as a disabled bundle rule re-enables it" do
    rule_text = "when command is foo:bar allow"
    {:ok, version} = Cog.Repository.Bundles.install(
      %{"name" => "foo",
        "version" => "1.0.0",
        "config_file" => %{
          "name" => "foo",
          "version" => "1.0.0",
          "commands" => %{"bar" => %{"rules" => [rule_text]}}}})

    [rule] = Cog.Repo.preload(version, [rules: :bundle_versions]).rules
    Cog.Repository.Rules.delete_or_disable(rule)
    %Rule{}=rule = Cog.Repository.Rules.rule(rule.id)
    refute rule.enabled

    # Now add the same rule for the site bundle
    {:ok, site_rule} = Cog.Repository.Rules.ingest(rule_text,
                                                   Cog.Repository.Bundles.site_bundle_version)

    # It's the same rule! But it's enabled now
    assert site_rule.id == rule.id
    assert site_rule.enabled
  end

  test "Deleting a site bundle rule that shadows the an identical disabled bundle rule re-disables it" do
    rule_text = "when command is foo:bar allow"
    {:ok, version} = Cog.Repository.Bundles.install(
      %{"name" => "foo",
        "version" => "1.0.0",
        "config_file" => %{
          "name" => "foo",
          "version" => "1.0.0",
          "commands" => %{"bar" => %{"rules" => [rule_text]}}}})

    [rule] = Cog.Repo.preload(version, [rules: :bundle_versions]).rules
    Cog.Repository.Rules.delete_or_disable(rule)
    %Rule{}=rule = Cog.Repository.Rules.rule(rule.id)
    refute rule.enabled

    site_version = Cog.Repository.Bundles.site_bundle_version

    # Now add the same rule for the site bundle
    {:ok, site_rule} = Cog.Repository.Rules.ingest(rule_text, site_version)

    # It's the same rule! But it's enabled now
    assert site_rule.id == rule.id
    assert site_rule.enabled

    # Now delete the rule
    Cog.Repository.Rules.delete_or_disable(site_rule)

    %Rule{}=final_rule = Cog.Repository.Rules.rule(site_rule.id)

    # The rule is still there, and still the same
    assert final_rule.id == rule.id

    # Now it's back to being disabled
    refute final_rule.enabled

    # It's no longer associated with the site bundle, but it is
    # associated with the original bundle
    refute final_rule.bundle_versions |> Enum.map(&(&1.id)) |> Enum.member?(site_version.id)
    assert final_rule.bundle_versions |> Enum.map(&(&1.id)) |> Enum.member?(version.id)
  end


end
