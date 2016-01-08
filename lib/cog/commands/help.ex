defmodule Cog.Commands.Help do
  use Spanner.GenCommand.Base, bundle: "#{Cog.embedded_bundle}"

  @moduledoc """
  Get help on all installed Cog bot commands.

    * `@bot #{Cog.embedded_bundle}:help` - list all known commands
    * `@bot #{Cog.embedded_bundle}:help "#{Cog.embedded_bundle}:help"` - list help for a specific command

  """

  use Cog.Models
  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Command.BundleResolver
  alias Piper.Command.SemanticError

  permission "help"
  rule "when command is #{Cog.embedded_bundle}:help must have #{Cog.embedded_bundle}:help"

  def handle_message(%{args: [], reply_to: reply_to}, state),
    do: {:reply, reply_to, "help", %{"commands" => commands}, state}
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

  defp commands do
    Queries.Command.names
    |> Repo.all
    |> Enum.map(&Enum.join(&1, ":"))
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
