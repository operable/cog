defmodule Cog.Models.CommandTest do
  use Cog.ModelCase
  alias Cog.Models.Bundle
  alias Cog.Models.Command
  alias Cog.Models.CommandOption
  alias Cog.Models.Rule
  alias Cog.Repo
  alias Piper.Permissions.Parser

  setup do
    {:ok, bundle} = Repo.insert(%Bundle{name: "test_bundle", config_file: %{}, manifest_file: %{}})
    {:ok, command} = Command.insert_new(%{name: "drop_database", bundle_id: bundle.id})
    {:ok, expr, _} = Parser.parse("when command is operable:drop_database must have drop_database:write")
    {:ok, rule} = Rule.insert_new(command, expr)
    {:ok, [bundle: bundle,
           command: command,
           rule: rule]}
  end

  test "command names are unique", %{bundle: bundle} do
    params = %{name: "pugbomb", bundle_id: bundle.id}
    {:ok, _} = Command.insert_new(params)
    assert {:error, %Ecto.Changeset{}} = Command.insert_new(params)
  end

  test "commands have rules", %{command: command, rule: rule} do
    preloaded = Cog.Repo.preload(command, :rules)
    assert [^rule] = preloaded.rules
  end

  test "commands have options", %{command: command} do
    {:ok, opt} = CommandOption.insert_new(command, %{name: "zone", type: "string", required: true})
    preloaded = Cog.Repo.preload(command, :options)
    assert [^opt] = preloaded.options
  end

  test "command option names are unique to each command", %{bundle: bundle, command: command} do
    {:ok, _} = CommandOption.insert_new(command, %{name: "term1", type: "bool", required: false})
    assert({:error, %Ecto.Changeset{}=_} = CommandOption.insert_new(command, %{name: "term1", type: "bool", required: false}))
    {:ok, command} = Command.insert_new(%{name: "wubba", bundle_id: bundle.id})
    assert({:ok, _} = CommandOption.insert_new(command, %{name: "term1", type: "bool", required: false}))
  end

  test "command names must be made up of word characters and dashes", %{bundle: bundle} do
    params = %{name: "weird:name", bundle_id: bundle.id}
    {:error, command} = Command.insert_new(params)
    assert %{errors: [name: "has invalid format"]} = command
  end
end
