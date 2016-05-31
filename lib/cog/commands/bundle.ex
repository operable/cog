defmodule Cog.Commands.Bundle do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.embedded_bundle

  alias Cog.Models.{Bundle, BundleVersion}
  alias Cog.Repository.Bundles

  @moduledoc """
  Manipulate and interrogate command bundle status.

  A bundle may be either `enabled` or `disabled`. If a bundle is
  enabled, chat invocations of commands contained within the bundle
  will be executed. If the bundle is disabled, on the other hand, no
  such commands will be run.

  Bundles may be enabled or disabled independently of whether or not
  any Relays are currently _running_ the bundles. The status of a
  bundle is managed centrally; when a Relay serving the bundle comes
  online, the status of the bundle is respected. Thus a bundle may be
  enabled, but not running on any Relays, just as it can be disabled,
  but running on _every_ Relay.

  This can be used to either quickly disable a bundle, or as the first
  step in deleting a bundle from the bot.

  Note that the `#{Cog.embedded_bundle}` bundle is a protected bundle;
  this bundle is always enabled and is in fact embedded in the bot
  itself. Core pieces of bot functionality would not work (including
  this very command itself!) if this bundle were ever disabled (though
  many functions would remain available via the REST API). As a
  result, calling either of the mutator subcommands `enable` or
  `disable` (see below) on the `#{Cog.embedded_bundle}` bundle is an
  error.

  USAGE
    bundle <subcommand>


  SUBCOMMANDS
    status

            bundle status <bundle_name>

       Shows the current status of the bundle, whether `enabled` or
       `disabled`. Additionally shows which Relays (if any) are running
       the code for the bundle.

       The `enable` and `disable` subcommands (see below) also return
       this information.

       Can be called on any bundle, including `#{Cog.embedded_bundle}`.

    enable

            bundle enable <bundle_name> [version]

      Enabling a bundle allows chat commands to be routed to it. Running
      this subcommand has no effect if a bundle is already enabled.

      Cannot be used on the `#{Cog.embedded_bundle}` bundle.

    disable

            bundle disable <bundle_name>

       Disabling a bundle prevents commands from being routed to it. The
       bundle is not uninstalled, and all custom rules remain
       intact. The bundle still exists, but commands in it will not be
       executed.

       A disabled bundle can be re-enabled using this the `enable`
       sub-command; see above.

       Running this subcommand has no effect if a bundle is already
       disabled.

       Cannot be used on the `#{Cog.embedded_bundle}` bundle.
  """

  permission "manage_commands"

  rule "when command is #{Cog.embedded_bundle}:bundle must have #{Cog.embedded_bundle}:manage_commands"

  def handle_message(%{args: ["status", bundle_name]} = req, state) do
    case Bundles.with_status_by_name(bundle_name) do
      nil ->
        {:error, req.reply_to, error_message({:not_found, bundle_name}), state}
      bundle ->
        {:reply, req.reply_to, "bundle-status", bundle, state}
    end
  end

  def handle_message(%{args: ["enable", bundle_name|args]} = req, state) do
    result = with {:ok, bundle_version}  <- parse_and_find_version(bundle_name, args),
                  {:ok, _bundle_version} <- check_for_enabled_version(bundle_name),
                  {:ok, bundle_version}  <- enable_bundle_version(bundle_version),
                  do: {:ok, bundle_version}

    case result do
      {:ok, bundle} ->
        {:reply, req.reply_to, "bundle-enable", Map.put(bundle, :status, :enabled), state}
      {:error, error} ->
        {:error, req.reply_to, error_message(error), state}
    end
  end

  def handle_message(%{args: ["disable", bundle_name]} = req, state) do
    result = with {:ok, bundle} <- find_enabled_bundle(bundle_name),
                  {:ok, bundle} <- disable_bundle(bundle),
                  do: {:ok, bundle}

    case result do
      {:ok, bundle} ->
        {:reply, req.reply_to, "bundle-disable", Map.put(bundle, :status, :disabled), state}
      {:error, error} ->
        {:error, req.reply_to, error_message(error), state}
    end
  end

  def handle_message(req, state) do
    {:error, req.reply_to, error_message(:invalid_invocation), state}
  end

  defp enable_bundle_version(%BundleVersion{}=bundle_version) do
    case Bundles.set_bundle_version_status(bundle_version, :enabled) do
      :ok ->
        {:ok, bundle_version}
      error ->
        error
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

  def check_for_enabled_version(bundle_name) do
    case Bundles.enabled_version_by_name(bundle_name) do
      {:error, {:not_found, bundle_name}} ->
        {:error, {:not_found, bundle_name}}
      {:error, {:disabled, bundle_version}} ->
        {:ok, bundle_version}
      {:ok, bundle_version} ->
        {:error, {:already_enabled, bundle_version}}
    end
  end

  def find_enabled_bundle(bundle_name) do
    case Bundles.enabled_version_by_name(bundle_name) do
      {:error, {:not_found, bundle_name}} ->
        {:error, {:not_found, bundle_name}}
      {:error, {:disabled, bundle_version}} ->
        {:error, {:already_disabled, bundle_version}}
      {:ok, bundle_version} ->
        {:ok, bundle_version}
    end
  end

  defp error_message({:not_found, name}),
    do: "Bundle #{inspect name} cannot be found."
  defp error_message({:not_found, name, version}),
    do: "Bundle #{inspect name} with version #{inspect to_string(version)} cannot be found."
  defp error_message({:protected_bundle, unquote(Cog.embedded_bundle)}),
    do: "Bundle #{inspect Cog.embedded_bundle} is protected and cannot be disabled."
  defp error_message({:protected_bundle, unquote(Cog.site_namespace)}),
    do: "Bundle #{inspect Cog.site_namespace} is protected and cannot be enabled."
  defp error_message({:protected_bundle, bundle_name}),
    do: "Bundle #{inspect bundle_name} is protected and cannot be enabled or disabled."
  defp error_message({:invalid_version, version}),
    do: "Version #{inspect version} could not be parsed."
  defp error_message({:already_enabled, %BundleVersion{bundle: %Bundle{name: bundle_name}, version: version}}),
    do: "Bundle #{inspect bundle_name} version #{inspect to_string(version)} is already enabled."
  defp error_message({:already_disabled, %BundleVersion{bundle: %Bundle{name: bundle_name}}}),
    do: "Bundle #{inspect bundle_name} is already disabled."
  defp error_message(:invalid_invocation),
    do: "That is not a valid invocation of the bundle command"
end
