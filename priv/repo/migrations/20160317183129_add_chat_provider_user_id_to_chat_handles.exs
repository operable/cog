defmodule Cog.Repo.Migrations.AddChatProviderUserIdToChatHandles do
  use Ecto.Migration
  use Cog.Queries

  def change do
    alter table(:chat_handles) do
      add :chat_provider_user_id, :text
    end

    create unique_index(:chat_handles, [:provider_id, :chat_provider_user_id])

    execute("UPDATE chat_handles SET chat_provider_user_id = handle")

    alter table(:chat_handles) do
      modify :chat_provider_user_id, :text, null: false
    end
  end
end
