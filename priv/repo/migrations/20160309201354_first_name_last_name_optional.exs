defmodule Cog.Repo.Migrations.FirstNameLastNameOptional do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :first_name, :text, null: true
      modify :last_name, :text, null: true
    end
  end
end
