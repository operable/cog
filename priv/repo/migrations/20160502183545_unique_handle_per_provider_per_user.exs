defmodule Cog.Repo.Migrations.UniqueHandlePerProviderPerUser do
  use Ecto.Migration

  def change do
    create unique_index(:chat_handles, [:user_id, :provider_id])
    drop index(:chat_handles, [:user_id, :provider_id, :handle])
  end
end
