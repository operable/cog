defmodule Cog.Queries.BundleVersions do
  use Cog.Queries
  alias Cog.Models.BundleVersion

  def with_bundle_name(bundle_name) do
    from bv in BundleVersion,
    join: b in assoc(bv, :bundle),
    where: b.name == ^bundle_name
  end
end
