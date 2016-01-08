defmodule Cog.Repo.Migrations.AddBundleCommandNameConstraint do
  use Ecto.Migration

  def change do
    create unique_index(:commands, [:name, :bundle_id], name: :bundled_command_name)
    drop unique_index(:commands, [:name])
  end
end
