defmodule Cog.Repo.Migrations.RemoveEnforcingFromCommands do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      remove :enforcing
    end
  end
end
