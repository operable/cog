defmodule Cog.Repo.Migrations.RemoveCommandExecution do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      remove :execution
    end
  end
end
