defmodule Cog.Commands.Bundle.Enable do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Models.BundleVersion
  alias Cog.Repository.Bundles

  Helpers.usage """
  Enable the specified version of a bundle, or the
  latest installed version if no version is given.

  Enabling a bundle allows chat commands to be routed to it. Running
  this subcommand has no effect if a bundle is already enabled.

  Cannot be used on the `#{Cog.Util.Misc.embedded_bundle}` bundle.

  USAGE
    bundle enable [FLAGS] <name> [<version>]

  ARGS
    name     Specifies the bundle to enable.
    version  The specific version of the bundle to enable. Defaults to latest installed version.

  FLAGS
    -h, --help  Display this usage info

  EXAMPLES

    bundle enable my-bundle 1.0.0
    bundle enable my-bundle
  """

  def enable(%{options: %{"help" => true}}, _args),
    do: show_usage
  def enable(_req, []),
    do: {:error, {:invalid_args, 1, 2}}
  def enable(_req, [_,_,_|_]),
    do: {:error, {:invalid_args, 1, 2}}
  def enable(_req, [bundle_name|maybe_version]) do
    with({:ok, bundle_version} <- parse_and_find_version(bundle_name, maybe_version),
         {:ok, bundle_version} <- enable_bundle_version(bundle_version)) do
      {:ok, "bundle-enable", Map.put(bundle_version, :status, :enabled)}
    end
  end

  ########################################################################

  defp parse_and_find_version(bundle_name, []) do
    case Bundles.highest_version_by_name(bundle_name) do
      nil ->
        {:error, {:not_found, bundle_name}}
      bundle ->
        {:ok, bundle}
    end
  end

  defp parse_and_find_version(bundle_name, [version]) do
    case Version.parse(version) do
      {:ok, version} ->
        case Bundles.with_name_and_version(bundle_name, version) do
          nil ->
            {:error, {:not_found, bundle_name, version}}
          bundle ->
            {:ok, bundle}
        end
      :error ->
        {:error, {:invalid_version, version}}
    end
  end

  defp enable_bundle_version(%BundleVersion{}=bundle_version) do
    case Bundles.set_bundle_version_status(bundle_version, :enabled) do
      :ok ->
        {:ok, bundle_version}
      error ->
        error
    end
  end


end
