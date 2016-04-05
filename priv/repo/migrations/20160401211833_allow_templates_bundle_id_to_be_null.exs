defmodule Cog.Repo.Migrations.AllowTemplatesBundleIdToBeNull do
  use Ecto.Migration

  def change do
    alter table(:templates) do
      modify :bundle_id, :uuid, null: true
    end
  end
end
