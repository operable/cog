defmodule Cog.Commands.Bundle.Disable do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "bundle-disable"

  alias Cog.Commands.Bundle
  alias Cog.Models.BundleVersion
  alias Cog.Repository.Bundles

  @description "Disable a bundle"

  @long_description """
  Disabling a bundle prevents commands from being routed to it. The
  bundle is not uninstalled, and all custom rules remain intact. The
  bundle still exists, but commands in it will not be executed.

  A disabled bundle can be re-enabled using the `bundle enable` command.

  Cannot be used on the `#{Cog.Util.Misc.embedded_bundle}` bundle.
  """

  @arguments "<name>"

  @examples """
  Disable the cfn bundle:

    bundle disable cfn
  """

  @output_description "Returns top-level data about the bundle and its new state"

  @output_example """
  [
    {
      "version": "0.5.0",
      "status": "disabled",
      "name": "cfn"
    }
  ]
  """
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle-disable must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req = %{args: [bundle_name]}, state) do
    result = with {:ok, bundle} <- find_enabled_bundle(bundle_name),
                  {:ok, bundle} <- disable_bundle(bundle) do
      {:ok, "bundle-disable", Map.put(bundle, :status, :disabled)}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Bundle.error(err), state}
    end
  end
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Bundle.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Bundle.error({:too_many_args, 1}), state}

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
