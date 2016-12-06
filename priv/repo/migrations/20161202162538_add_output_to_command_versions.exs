defmodule Cog.Repo.Migrations.AddOutputToCommandVersions do
  use Ecto.Migration

  def change do
    alter table(:command_versions) do
      add :output, :string
    end
  end
end
