defmodule Cog.Repo.Migrations.AddStructuredDocsFieldsToCommandVersions do
  use Ecto.Migration

  def change do
    alter table(:command_versions) do
      add :long_description, :text,   null: true
      add :examples,         :text,   null: true
      add :notes,            :text,   null: true
      add :arguments,        :string, null: true
      add :subcommands,      :json,   null: true
    end
  end
end
