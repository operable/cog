defmodule Cog.Repo.Migrations.RemoveNullProvider do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM chat_providers WHERE name = 'null'
    """
  end

  def down do
    execute """
    INSERT INTO chat_providers(name, inserted_at, updated_at)
    VALUES('null', 'now', 'now')
    """
  end

end
