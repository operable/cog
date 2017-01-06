defmodule Cog.Repo.Migrations.RemoveSubcommandsFromCommandVersions do
  use Ecto.Migration

  def change do
    alter table(:command_versions) do
      remove :subcommands
    end
  end
end
