defmodule RuleTest do
  use Cog.ModelCase
  alias Cog.Models.Bundle
  alias Cog.Models.Command
  alias Cog.Models.Rule

  setup do
    bundle = Bundle.changeset(%Bundle{}, %{name: "test_bundle", config_file: %{}, manifest_file: %{}}) |> Repo.insert!
    {:ok, command} = Command.insert_new(%{name: "pugbomb", bundle_id: bundle.id})
    {:ok, [command: command]}
  end

  test "a parse tree is required", %{command: command} do
    assert {:error, _} = Rule.insert_new(command, %{})
  end

  test "all rules must be unique", %{command: command} do
    rule_text = "when command is s3:list must have s3:delete"
    {:ok, expr, _} = Piper.Permissions.Parser.parse(rule_text)
    {:ok, _rule} = Rule.insert_new(command, expr)

    result = Rule.insert_new(command, expr)
    assert {:error, %Ecto.Changeset{errors: [no_dupes: "has already been taken"]}} = result
  end

  defmodule Permissions do
    use Cog.ModelCase

    setup do
      bundle = Bundle.changeset(%Bundle{}, %{name: "test_bundle", config_file: %{}, manifest_file: %{}}) |> Repo.insert!
      rule_text = "when command is s3:list must have s3:delete"
      {:ok, expr, _} = Piper.Permissions.Parser.parse(rule_text)
      {:ok, command} = Command.insert_new(%{name: "pugbomb", bundle_id: bundle.id})
      {:ok, rule} = Rule.insert_new(command, expr)
      {:ok, [rule: rule,
             permission: permission("pugbomb:create")]}
    end

    test "permissions may be assigned to an rule", %{rule: rule, permission: permission} do
      :ok = Permittable.grant_to(rule, permission)
      assert_permission_is_granted(rule, permission)
    end

    test "permission assignment is idempotent", %{rule: rule, permission: permission} do
      :ok = Permittable.grant_to(rule, permission)
      assert :ok = Permittable.grant_to(rule, permission)
    end

  end
end
