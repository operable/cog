defmodule Cog.Repo.Migrations.EnabledBundleVersions do
  use Ecto.Migration

  def change do
    execute """
    CREATE TABLE enabled_bundle_versions(
      bundle_id uuid NOT NULL,
      version int[] NOT NULL,
      PRIMARY KEY(bundle_id, version),
      FOREIGN KEY(bundle_id, version)
        REFERENCES bundle_versions_v2(bundle_id, version)
        ON DELETE CASCADE ON UPDATE CASCADE,
      UNIQUE(bundle_id)
    )
    """

    execute """
    CREATE OR REPLACE FUNCTION enable_bundle_version(p_bundle_id bundles_v2.id%TYPE, p_version bundle_versions_v2.version%TYPE)
    RETURNS VOID
    LANGUAGE plpgsql
    AS $$
    BEGIN
      INSERT INTO enabled_bundle_versions(bundle_id, version)
      VALUES(p_bundle_id, p_version);
    EXCEPTION
      WHEN unique_violation THEN
        DELETE FROM enabled_bundle_versions
        WHERE bundle_id = p_bundle_id;

        INSERT INTO enabled_bundle_versions(bundle_id, version)
        VALUES(p_bundle_id, p_version);
    END;
    $$
    """

    execute """
    CREATE OR REPLACE FUNCTION disable_bundle_version(p_bundle_id bundles_v2.id%TYPE, p_version bundle_versions_v2.version%TYPE)
    RETURNS VOID
    LANGUAGE sql
    AS $$
      DELETE FROM enabled_bundle_versions
      WHERE bundle_id = p_bundle_id
        AND version = p_version;;
    $$
    """

  end

end
