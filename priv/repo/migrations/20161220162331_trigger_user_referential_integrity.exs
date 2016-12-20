defmodule Cog.Repo.Migrations.TriggerUserReferentialIntegrity do
  use Ecto.Migration

  def change do
    execute """
    ALTER TABLE triggers
    ADD CONSTRAINT triggers_as_user_fkey
    FOREIGN KEY(as_user) REFERENCES users(username)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
    """
  end
end
