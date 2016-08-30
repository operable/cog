defmodule Cog.Repo.Migrations.AddStructuredDocsFieldsToBundleVersions do
  use Ecto.Migration

  def change do
    alter table(:bundle_versions) do
      add :long_description, :text,   null: true
      add :author,           :string, null: true
      add :homepage,         :string, null: true
    end
  end
end
