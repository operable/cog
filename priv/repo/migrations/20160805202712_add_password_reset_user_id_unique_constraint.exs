defmodule Cog.Repo.Migrations.AddPasswordResetUserIdUniqueConstraint do
  use Ecto.Migration

  def change do
    create unique_index(:password_resets, [:user_id])
  end
end
