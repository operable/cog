defmodule Cog.Repo.Migrations.AddOutputToCommandVersions do
  use Ecto.Migration

  def change do
    alter table(:command_versions) do
      add :output, :json, null: false, default: "{}"
    end
  end
end
