defmodule Cog.Repo.Migrations.RenameCommandOptionDescToDescription do
  use Ecto.Migration

  def change do
    rename table(:command_options), :desc, to: :description
  end
end
