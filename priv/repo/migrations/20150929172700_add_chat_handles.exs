defmodule Cog.Repo.Migrations.AddChatHandles do
  use Ecto.Migration

  def up do
    create table(:chat_providers, primary_key: true) do
      add :name, :text, null: false

      timestamps
    end

    create unique_index(:chat_providers, [:name])

    execute """
    INSERT INTO chat_providers(name, inserted_at, updated_at)
    VALUES ('Slack', now(), now()),
           ('HipChat', now(), now()),
           ('irc', now(), now()),
           ('Test', now(), now())
    """

    create table(:chat_handles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :provider_id, references(:chat_providers, type: :serial), null: false
      add :handle, :text, null: false

      timestamps
    end
    # User can have multiple handles per provider
    create unique_index(:chat_handles, [:user_id, :provider_id, :handle])
    # Handles must be unique per provider
    create unique_index(:chat_handles, [:provider_id, :handle])
  end

  def down do
    execute "DROP TABLE chat_handles;"
    execute "DROP TABLE chat_providers;"
  end
end
