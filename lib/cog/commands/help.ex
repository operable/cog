defmodule Cog.Commands.Help do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  use Cog.Models
  alias Cog.Repo
  alias Cog.Repository.{Bundles, Commands}
  alias Cog.Commands.Help.{BundlesFormatter, BundleFormatter, CommandFormatter}

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
    grouped_bundles = %{enabled: Repo.preload(Bundles.enabled, :bundle),
                        disabled: Repo.preload(Bundles.highest_disabled_versions, :bundle)}
    formatted_bundles = BundlesFormatter.format(grouped_bundles)
    {:reply, req.reply_to, "text", [%{body: formatted_bundles}], state}
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
            body = bundle_version
            |> Repo.preload(:bundle)
            |> BundleFormatter.format

            {:ok, body}
        end
      [bundle_name, command_name] ->
        full_command_name = bundle_name <> ":" <> command_name

        command_version = full_command_name
        |> Commands.with_status_by_any_name
        |> Repo.preload([:bundle_version, :options])

        case command_version do
          [] ->
            {:error, "Command #{inspect(full_command_name)} not found"}
          [%CommandVersion{} = command_version] ->
            {:ok, CommandFormatter.format(command_version)}
        end
    end

    case response do
      {:ok, body} ->
        {:reply, req.reply_to, "text", [%{body: body}], state}
      {:error, error} ->
        {:error, req.reply_to, error, state}
    end
  end

  def handle_message(req, state) do
    {:reply, req.reply_to, "usage", %{usage: @moduledoc}, state}
  end
end
