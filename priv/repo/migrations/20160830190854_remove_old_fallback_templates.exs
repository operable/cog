defmodule Cog.Repo.Migrations.RemoveOldFallbackTemplates do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM templates
    WHERE adapter != 'GREENBAR_PROVIDER'
    AND bundle_version_id IS NULL;
    """
  end

  def down do
    files = ["20160705194714_insert_self_registration_templates.exs",
             "20160406172300_insert_error_templates.exs",
             "20160401212441_insert_fallback_templates.exs"]
    Enum.each(files, &(Code.eval_file(&1, __DIR__)))

    Cog.Repo.Migrations.InsertSelfRegistrationTemplates.change
    Cog.Repo.Migrations.InsertErrorTemplates.change
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
end
