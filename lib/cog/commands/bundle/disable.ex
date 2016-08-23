defmodule Cog.Commands.Bundle.Disable do
  require Cog.Commands.Helpers, as: Helpers

  alias Cog.Repository.Bundles
  alias Cog.Models.BundleVersion

  Helpers.usage """
  Disable a bundle.

  Disabling a bundle prevents commands from being routed to it. The
  bundle is not uninstalled, and all custom rules remain intact. The
  bundle still exists, but commands in it will not be executed.

  A disabled bundle can be re-enabled using this the `enable`
  sub-command.

  Cannot be used on the `#{Cog.Util.Misc.embedded_bundle}` bundle.

  USAGE
    bundle disable [FLAGS] <name>

  ARGS
    name  Specifies the bundle to disable.

  FLAGS
    -h, --help  Display this usage info

  EXAMPLES

    bundle disable my-bundle
  """

  def disable(%{options: %{"help" => true}}, _args),
    do: show_usage
  def disable(_req, [bundle_name]) do
    with({:ok, bundle} <- find_enabled_bundle(bundle_name),
         {:ok, bundle} <- disable_bundle(bundle)) do
      {:ok, "bundle-disable", Map.put(bundle, :status, :disabled)}
    end
  end
  def disable(_req, []),
    do: {:error, {:not_enough_args, 1}}
  def disable(_req, _),
    do: {:error, {:too_many_args, 1}}

  ########################################################################

  defp find_enabled_bundle(bundle_name) do
    case Bundles.enabled_version_by_name(bundle_name) do
      {:error, {:not_found, bundle_name}} ->
        {:error, {:not_found, bundle_name}}
      {:error, {:disabled, bundle_version}} ->
        {:error, {:already_disabled, bundle_version}}
      {:ok, bundle_version} ->
        {:ok, bundle_version}
    end
  end

  defp disable_bundle(%BundleVersion{}=bundle_version) do
    case Bundles.set_bundle_version_status(bundle_version, :disabled) do
      :ok ->
        {:ok, bundle_version}
      error ->
        error
    end
  end

end
