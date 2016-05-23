defmodule Cog.Repo.Migrations.EnabledBundleVersionRegistrationView do
  use Ecto.Migration

  def change do
    execute """
    CREATE VIEW enabled_bundle_version_view AS
    SELECT bv.bundle_id AS bundle_id,
           bv.id AS bundle_version_id
      FROM enabled_bundle_versions AS e
      JOIN bundle_versions_v2 AS bv
        ON (e.bundle_id, e.version) = (bv.bundle_id, bv.version);
    """
  end

end
