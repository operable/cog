defmodule Cog.Repo.Migrations.AddExecution do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :execution, :string, default: "multiple"
    end
  end
end
