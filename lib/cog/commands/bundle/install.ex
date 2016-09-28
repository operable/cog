defmodule Cog.Commands.Bundle.Install do
  alias Cog.Repository.Bundles
  alias Cog.BundleRegistry
  alias Cog.Models.BundleVersion
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Install latest or specified version of bundle from registry.

  USAGE
    bundle install <bundle> [<version>]

  ARGS
    bundle   The name of a bundle
    version  The version of a bundle

  FLAGS
    -h, --help  Display this usage info
  """

  def install(%{options: %{"help" => true}}, _args),
    do: show_usage
  def install(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def install(req, [bundle]),
    do: install(req, [bundle, "latest"])
  def install(_req, [bundle, version]) do
    case BundleRegistry.get_config(bundle, version) do
      {:ok, %{"name" => name, "version" => version} = config} ->
        revised_config = %{"name" => name,
                           "version" => version,
                           "config_file" => config}

        case Bundles.install(revised_config) do
          {:ok, %BundleVersion{bundle: bundle} = bundle_version} ->
            bundle = %{bundle | versions: [bundle_version]}
            rendered = Cog.V1.BundlesView.render("show.json", %{bundle: bundle})
            {:ok, "bundle-install", rendered[:bundle]}
          {:error, {:db_errors, [version: {"has already been taken", []}]}} ->
            {:error, {:already_installed, bundle, version}}
          {:error, error} ->
            {:error, error}
        end
      {:error, error} ->
        {:error, error}
    end
  end
end
