defmodule RuleIngestionTest do
  use Cog.ModelCase
  alias Piper.Permissions.Parser

  setup do
    site = ensure_site_bundle
    {:ok, [site: site]}
  end

  test "a valid rule gets parsed and saved", %{site: site} do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"
    expr = Parser.rule_to_json!(expr(rule_text))

    {:ok, %Cog.Models.Rule{parse_tree: ^expr}} = Cog.RuleIngestion.ingest(rule_text, site)
  end

  test "invalid rules are not ingested and return a syntax error message", %{site: site} do
    actual = Cog.RuleIngestion.ingest("monkeys monkeys monkeys", site)
    expected = {:error, [invalid_rule_syntax: "(Line: 1, Col: 0) syntax error before: \"monkeys\"."]}
    assert ^expected = actual
  end

  test "a rule for an unrecognized command is not inserted", %{site: site} do
    permission("s3:delete")
    rule_text = "when command is cog:monkeys with option[op] == 'delete' must have s3:delete"

    actual = Cog.RuleIngestion.ingest(rule_text, site)
    assert({:error, [{:unrecognized_command, "cog:monkeys"}]} = actual)
  end

  test "ingesting a rule you've already ingested returns the exact same rule that was inserted earlier", %{site: site} do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    {:ok, %Cog.Models.Rule{id: id}} = Cog.RuleIngestion.ingest(rule_text, site)
    assert {:ok, %Cog.Models.Rule{id: ^id}} = Cog.RuleIngestion.ingest(rule_text, site)
  end

  test "a rule is linked by database references to the required permissions", %{site: site} do
    command("s3")
    permission = permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    rule = rule_text
    |> rule(site)
    |> Repo.preload(:permissions)

    assert [^permission] = rule.permissions
  end

  test "if multiple permissions are required, all are linked", %{site: site} do
    command("s3")
    permissions = ["s3:delete", "s3:admin", "system:superpower"]
    |> Enum.map(&permission(&1)) |> Enum.sort

    rule_text = """
    when command is cog:s3
    with option[op] == 'delete'
    must have s3:delete or
              s3:admin or
              system:superpower
    """
    rule = rule(rule_text, site) |> Repo.preload(:permissions)
    retrieved_permissions = rule.permissions |> Enum.sort

    assert ^permissions = retrieved_permissions
  end

  test "all permissions must be present in the database to ingest a rule", %{site: site} do
    command("s3")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    assert {:error, [unrecognized_permission: "s3:delete"]} = Cog.RuleIngestion.ingest(rule_text, site)
  end

  test "a parse tree can round-trip to and from the database", %{site: site} do
    command = command("s3")
    permission("s3:delete")
    inserted_rule = rule("when command is cog:s3 with option[op] == 'delete' must have s3:delete", site)

    %Cog.Models.Rule{parse_tree: retrieved_tree} = Repo.one!(Ecto.assoc(command, :rules))
    assert ^retrieved_tree = inserted_rule.parse_tree
  end

end
