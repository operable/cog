defmodule Cog.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :first_name, :text, null: false
      add :last_name, :text, null: false
      add :email_address, :text, null: false

      timestamps
    end
  end
end
