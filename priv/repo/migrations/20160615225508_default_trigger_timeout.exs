defmodule Cog.Repo.Migrations.DefaultTriggerTimeout do
  use Ecto.Migration

  def change do
    alter table(:triggers) do
      modify :timeout_sec, :integer, null: false, default: 30
    end
  end
end
