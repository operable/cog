defmodule Cog.Repo.Migrations.AddCallingConvention do
  use Ecto.Migration

  def change do
    alter table(:commands) do
      add :calling_convention, :string, default: "bound"
    end

    execute """
ALTER TABLE commands
  ADD CONSTRAINT calling_convention_check
    CHECK(calling_convention = 'all' AND enforcing = false OR calling_convention = 'bound');
    """
  end
end
