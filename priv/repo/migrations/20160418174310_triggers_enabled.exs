defmodule Cog.Repo.Migrations.TriggersEnabled do
  use Ecto.Migration

  def change do
    rename table(:triggers), :active, to: :enabled
  end
end
