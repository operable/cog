defmodule Cog.Repo.Migrations.VarcharToText do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      modify :value, :text, null: false
    end
    alter table(:commands) do
      modify :execution, :text, default: "multiple"
      modify :calling_convention, :text, default: "bound"
    end
    alter table(:templates) do
      modify :name, :text, null: false
      modify :adapter, :text, null: false
    end
  end
end
