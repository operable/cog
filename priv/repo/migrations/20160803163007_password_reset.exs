defmodule Cog.Repo.Migrations.PasswordReset do
  use Ecto.Migration

  def change do
    create table(:password_resets, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid), null: false

      timestamps
    end
  end
end
