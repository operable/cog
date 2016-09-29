defmodule Cog.Commands.Help do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Repo
  alias Cog.Models.BundleVersion
  alias Cog.Models.CommandVersion
  alias Cog.Repository.{Bundles, Commands}

  @description "Show documentation for available commands"

  @examples """
  View all installed bundles:

    operable:help

  View documentation for a bundle:

    operable:help mist

  View documentation for a command:

    operable:help mist:ec2-find
  """

  @arguments "[<bundle> | <bundle:command>]"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:help allow"

  def handle_message(%{args: []} = req, state) do
    bundles = %{enabled: Repo.preload(Bundles.enabled, :bundle),
                disabled: Repo.preload(Bundles.highest_disabled_versions, :bundle)}
    {:reply, req.reply_to, "help-bundles", bundles, state}
  end

  def handle_message(%{args: [bundle_or_command]} = req, state) do
    response = case String.split(bundle_or_command, ":") do
      [bundle_name] ->
        bundle_version = bundle_name
        |> Bundles.with_status_by_name

        case bundle_version do
          nil ->
            {:error, "Bundle #{inspect(bundle_name)} not found"}
          %BundleVersion{} = bundle_version ->
            bundle_version = Repo.preload(bundle_version, :bundle)
            rendered = Cog.V1.BundleVersionView.render("bundle_version.json", %{bundle_version: bundle_version})
            {:ok, {:bundle, rendered}}
        end
      [bundle_name, command_name] ->
        full_command_name = bundle_name <> ":" <> command_name

        command_version = full_command_name
        |> Commands.with_status_by_any_name
        |> Commands.preloads_for_help

        case command_version do
          [] ->
            {:error, "Command #{inspect(full_command_name)} not found"}
          [%CommandVersion{bundle_version: %BundleVersion{config_file: %{"cog_bundle_version" => version}}} = command] when version < 4 ->
            {:ok, {:documentation, command.documentation}}
          [%CommandVersion{} = command_version] ->
            rendered = Cog.V1.CommandVersionView.render("command_version_help.json", %{command_version: command_version})
            {:ok, {:command, rendered}}
        end
    end

    case response do
      {:ok, {:bundle, bundle}} ->
        {:reply, req.reply_to, "help-bundle", bundle, state}
      {:ok, {:command, command}} ->
        {:reply, req.reply_to, "help-command", command, state}
      {:ok, {:documentation, documentation}} ->
        {:reply, req.reply_to, "help-command-documentation", %{documentation: documentation}, state}
      {:ok, body} ->
        {:reply, req.reply_to, body, state}
      {:error, error} ->
        {:error, req.reply_to, error, state}
    end
  end

  def handle_message(req, state) do
    {:reply, req.reply_to, "usage", %{usage: @moduledoc}, state}
  end
end
