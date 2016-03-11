defmodule RuleIngestionTest do
  use Cog.ModelCase
  alias Piper.Permissions.Parser

  test "a valid rule gets parsed and saved" do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"
    expr = Parser.rule_to_json!(expr(rule_text))

    {:ok, %Cog.Models.Rule{parse_tree: ^expr}} = Cog.RuleIngestion.ingest(rule_text)
  end

  test "invalid rules are not ingested and return a syntax error message" do
    actual = Cog.RuleIngestion.ingest("monkeys monkeys monkeys")
    expected = {:error, [invalid_rule_syntax: "(Line: 1, Col: 0) syntax error before: \"monkeys\"."]}
    assert ^expected = actual
  end

  test "a rule for an unrecognized command is not inserted" do
    permission("s3:delete")
    rule_text = "when command is cog:monkeys with option[op] == 'delete' must have s3:delete"

    actual = Cog.RuleIngestion.ingest(rule_text)
    assert({:error, [{:unrecognized_command, "cog:monkeys"}]} = actual)
  end

  test "ingesting a rule you've already ingested is not allowed" do
    command("s3")
    permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    {:ok, %Cog.Models.Rule{}} = Cog.RuleIngestion.ingest(rule_text)
    assert {:error, [no_dupes: "has already been taken"]} = Cog.RuleIngestion.ingest(rule_text)
  end

  test "a rule is linked by database references to the required permissions" do
    command("s3")
    permission = permission("s3:delete")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    rule = rule_text
    |> rule
    |> Repo.preload(:permissions)

    assert [^permission] = rule.permissions
  end

  test "if multiple permissions are required, all are linked" do
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
    rule = rule(rule_text) |> Repo.preload(:permissions)
    retrieved_permissions = rule.permissions |> Enum.sort

    assert ^permissions = retrieved_permissions
  end

  test "all permissions must be present in the database to ingest a rule" do
    command("s3")
    rule_text = "when command is cog:s3 with option[op] == 'delete' must have s3:delete"

    assert {:error, [unrecognized_permission: "s3:delete"]} = Cog.RuleIngestion.ingest(rule_text)
  end

  test "a parse tree can round-trip to and from the database" do
    command = command("s3")
    permission("s3:delete")
    inserted_rule = rule("when command is cog:s3 with option[op] == 'delete' must have s3:delete")

    %Cog.Models.Rule{parse_tree: retrieved_tree} = Repo.one!(Ecto.assoc(command, :rules))
    assert ^retrieved_tree = inserted_rule.parse_tree
  end

end
