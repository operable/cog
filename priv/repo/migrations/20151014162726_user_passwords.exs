defmodule Cog.Repo.Migrations.UserPasswords do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :password_digest, :text, null: true
    end
  end
end
