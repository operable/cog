defmodule Cog.Repo.Migrations.AddOldFallbackTemplatesAgain do
  use Ecto.Migration

  def up do
    Code.eval_file("20160401212441_insert_fallback_templates.exs", __DIR__)
    Cog.Repo.Migrations.InsertFallbackTemplates.change

    # This one was added in InsertFallbackTemplates, but we removed it
    # in a later migration
    execute """
    DELETE FROM templates
    WHERE adapter = 'hipchat'
    AND name = 'json'
    AND bundle_version_id IS NULL
    """
  end

  def down do
    execute """
    DELETE FROM templates
    WHERE adapter != 'GREENBAR_PROVIDER'
    AND bundle_version_id IS NULL;
    """
  end

end
