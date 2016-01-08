defmodule Cog.Repo.Migrations.UserLoginNames do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :text, null: false
    end
    create unique_index(:users, [:username])
  end
end
