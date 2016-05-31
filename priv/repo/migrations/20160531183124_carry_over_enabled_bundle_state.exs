defmodule Cog.Repo.Migrations.CarryOverEnabledBundleState do
  use Ecto.Migration

  def change do

    execute """
    INSERT INTO enabled_bundle_versions
    SELECT b_v2.id, bv.version
    FROM bundle_versions_v2 AS bv
    JOIN bundles_v2 AS b_v2
      ON b_v2.id = bv.bundle_id
    JOIN bundles AS old_bundles
      ON old_bundles.name = b_v2.name
     AND string_to_array(old_bundles.version, '.')::int[] = bv.version
    WHERE old_bundles.enabled IS TRUE
    """

  end
end
