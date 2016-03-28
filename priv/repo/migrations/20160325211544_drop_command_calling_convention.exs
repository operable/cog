defmodule Cog.Repo.Migrations.DropCommandCallingConvention do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      remove :calling_convention
    end
  end
end
