defmodule Cog.Repo.Migrations.ParseTreeIsJson do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE rules_v2 ALTER COLUMN parse_tree TYPE jsonb USING parse_tree::jsonb;
    """
  end

  def down do
    execute """
    ALTER TABLE rules_v2 ALTER COLUMN parse_tree TYPE text USING parse_tree::text;
    """
  end

end
