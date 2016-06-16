defmodule Cog.Commands.Bundle.Info do
  alias Cog.Repository.Bundles
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Show detailed information about a specific bundle.

  USAGE
    bundle info [FLAGS] <bundle>

  ARGS
    bundle   The name of a bundle

  FLAGS
    -h, --help  Display this usage info
  """

  def info(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def info(_req, [bundle_name]) do
    case Bundles.bundle_by_name(bundle_name) do
      nil ->
        {:error, {:resource_not_found, "bundle", bundle_name}}
      bundle ->
        rendered = Cog.V1.BundlesView.render("show.json", %{bundle: bundle})
        {:ok, "bundle-info", rendered[:bundle]}
    end
  end
  def info(_req, []),
    do: {:error, {:not_enough_args, 1}}

end
