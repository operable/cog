defmodule Cog.Repo.Migrations.AddChatProviderState do
  use Ecto.Migration

  def change do
    alter table(:chat_providers) do
      add :data, :jsonb, null: true
    end
  end

end
