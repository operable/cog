defmodule Cog.Commands.Bundle.Versions do
  alias Cog.Repository.Bundles
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Lists currently installed versions of a given bundle.

  USAGE
    bundle versions [FLAGS] <bundle>

  ARGS
    bundle   The name of a bundle

  FLAGS
    -h, --help  Display this usage info
  """

  def versions(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def versions(_req, [bundle_name]) do
    case Bundles.bundle_by_name(bundle_name) do
      nil ->
        {:error, {:resource_not_found, "bundle", bundle_name}}
      bundle ->
        versions = Bundles.versions(bundle)
        rendered = Cog.V1.BundleVersionView.render("index.json", %{bundle_versions: versions})
        {:ok, "bundle-versions", rendered[:bundle_versions]}
    end
  end
  def versions(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def versions(_req, _),
    do: {:error, {:too_many_args, 1}}

end
