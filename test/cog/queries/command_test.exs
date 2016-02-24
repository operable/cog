defmodule Cog.Queries.Command.Test do
  use Cog.ModelCase

  alias Cog.Queries
  alias Cog.Models.Bundle
  alias Cog.Models.Command
  alias Cog.Repo

  setup do
    {:ok, bundle} = Repo.insert(%Bundle{name: "test_bundle", config_file: %{}, manifest_file: %{}})
    {:ok, qualified_command} = Command.insert_new(%{name: "drop_database", bundle_id: bundle.id})
    {:ok, shorthand_command} = Command.insert_new(%{name: "test_bundle", bundle_id: bundle.id})
    {:ok, [bundle: bundle.name,
           qualified_command: qualified_command.name,
           shorthand_command: shorthand_command.name]}
  end

  test "qualified_name", %{bundle: bundle_name, qualified_command: command_name} do
    command = fetch_command(bundle_name, command_name)

    assert bundle_name == command.bundle.name
    assert command_name == command.name
  end

  test "shorthand_name", %{bundle: bundle_name, shorthand_command: command_name} do
    command = fetch_command(command_name)

    assert bundle_name == command.bundle.name
    assert command_name == command.name
  end

  defp fetch_command(bundle, command) do
    fetch_command(bundle <> ":" <> command)
  end
  defp fetch_command(command) do
    Queries.Command.named(command)
    |> Ecto.Query.preload(:bundle)
    |> Repo.one!
  end

end
