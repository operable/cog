defmodule Cog.Repo.Migrations.DropCommandVersions do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      remove :version
    end
  end
end
