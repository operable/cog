defmodule Cog.Repo.Migrations.AddSshAdapter do
  use Ecto.Migration

  alias Cog.Repo

  def up do
    execute """
    INSERT INTO chat_providers ( name, inserted_at, updated_at )
    VALUES ( 'ssh', NOW(), NOW() )
    """
  end

  def down do
    execute "DELETE FROM chat_providers where name='ssh'"
  end
end
