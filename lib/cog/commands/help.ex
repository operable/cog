defmodule Cog.Commands.Help do
  use Spanner.GenCommand.Base, bundle: "#{Cog.embedded_bundle}", enforcing: false

  @moduledoc """
  Get help on all installed Cog bot commands.

    * `@bot #{Cog.embedded_bundle}:help` - list all enabled commands
    * `@bot #{Cog.embedded_bundle}:help --disabled` - list all disabled commands
    * `@bot #{Cog.embedded_bundle}:help --all` - list all known commands, enabled and disabled
    * `@bot #{Cog.embedded_bundle}:help "#{Cog.embedded_bundle}:help"` - list help for a specific command

  """

  use Cog.Models
  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Command.BundleResolver
  alias Piper.Command.SemanticError

  option "all", type: "bool", required: false
  option "disabled", type: "bool", required: false

  def handle_message(%{args: [], options: options, reply_to: reply_to}, state),
    do: {:reply, reply_to, "help", %{"commands" => commands(options)}, state}
  def handle_message(%{args: [command], reply_to: reply_to}, state) do
    case find_command(command) do
      {:ok, command} ->
        case documentation(command) do
          {:ok, docs} ->
            {:reply, reply_to, "help", docs, state}
          {:error, msg} ->
            {:reply, reply_to, msg, state}
        end
      {:error, msg} ->
        {:reply, reply_to, msg, state}
    end
  end
  def handle_message(%{reply_to: reply_to}, state),
    do: {:reply, reply_to, "Call this command with a 0 or 1 argument only", state}

  defp find_command(command) do
    case String.contains?(command, ":") do
      false ->
        case BundleResolver.find_bundle(command) do
          {:ok, bundle} ->
            {:ok, bundle <> ":" <> command}
          error ->
            SemanticError.format_error(error)
        end
      true ->
        {:ok, command}
    end
  end

  defp commands(options) do
    IO.inspect(options)
    Queries.Command.names
    |> Repo.all
    |> Enum.filter(&determine_inclusion(&1, options))
    |> Enum.map(fn([bundle, command, _]) -> "#{bundle}:#{command}" end)
    |> Enum.sort
  end

  defp determine_inclusion([_, _, enabled], %{"disabled" => true}) do
    true
    if enabled do
      false
    end
  end
  defp determine_inclusion([_, _, _], %{"all" => true}), do: true
  defp determine_inclusion([_, _, enabled], _) do
    false
    if enabled do
      true
    end
  end

  defp documentation(command_name) do
    command = command_name
    |> Queries.Command.named
    |> Repo.one

    if command != nil do
      {:ok, %{"command" => command_name, "documentation" => command.documentation}}
    else
      {:error, "Documentation for command '#{command_name}' is unavailable."}
    end
  end
end
