defmodule Cog.Repo.Migrations.AddDescriptionToCommandVersions do
  use Ecto.Migration

  def change do
    alter table(:command_versions_v2) do
      add :description, :text
    end
  end
end
