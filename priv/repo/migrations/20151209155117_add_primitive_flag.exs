defmodule :"Elixir.Cog.Repo.Migrations.Add_primitive_flag" do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :primitive, :bool, default: false
    end
  end
end
