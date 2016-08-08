defmodule Cog.Repo.Migrations.RemoveIrcProvider do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM chat_providers WHERE name = 'irc'
    """
  end

  def down do
    execute """
    INSERT INTO chat_providers(name, inserted_at, updated_at)
    VALUES('irc', 'now', 'now')
    """
  end

end
