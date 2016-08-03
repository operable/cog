defmodule Cog.Repo.Migrations.AddUniqueConstraintToUsersEmailAddress do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:email_address])
  end
end
