defmodule Cog.Repo.Migrations.AddCommandDocumentation do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :documentation, :text, null: true
    end
  end
end
