defmodule Cog.Repo.Migrations.AddEnforcing do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :enforcing, :bool, default: true
    end
  end
end
