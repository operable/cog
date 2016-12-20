defmodule Cog.Commands.Bundle.Enable do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "bundle-enable"

  alias Cog.Commands.Bundle
  alias Cog.Models.BundleVersion
  alias Cog.Repository.Bundles

  @description "Enables a specific version of a bundle"

  @long_description """
  Enable the specified version of a bundle, or the
  latest installed version if no version is given.

  Enabling a bundle allows chat commands to be routed to it. Running
  this subcommand has no effect if a bundle is already enabled.

  Cannot be used on the `#{Cog.Util.Misc.embedded_bundle}` bundle.
  """

  @arguments "<name> [<version>]"

  @examples """
  Enable version 0.5.0 of the cfn bundle:

    bundle enable cfn 0.5.0

  Enable the highest version currently installed of the cfn bundle:

    bundle enable cfn
  """

  @output_description "Returns top-level data about the bundle and its new state"

  @output_example """
  [
    {
      "version": "0.5.0",
      "status": "enabled",
      "name": "cfn"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle-enable must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Bundle.error({:invalid_args, 1, 2}), state}
  def handle_message(req = %{args: [_,_,_|_]}, state),
    do: {:error, req.reply_to, Bundle.error({:invalid_args, 1, 2}), state}
  def handle_message(req = %{args: [bundle_name|maybe_version]}, state) do
    result = with {:ok, bundle_version} <- parse_and_find_version(bundle_name, maybe_version),
                  {:ok, bundle_version} <- enable_bundle_version(bundle_version) do
      {:ok, "bundle-enable", Map.put(bundle_version, :status, :enabled)}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Bundle.error(err), state}
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
