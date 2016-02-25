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
  alias Cog.Command.CommandResolver
  alias Piper.Command.SemanticError

  option "all", type: "bool", required: false
  option "disabled", type: "bool", required: false

  def handle_message(%{args: [], options: options, reply_to: reply_to}, state) do
    case commands(options) do
      # We do not allow embedded commands to be disabled, so this would only happen for looking for disabled commands
      [] -> {:reply, reply_to, "There are no disabled commands.", state}
      commands -> {:reply, reply_to, "help", %{"commands" => commands}, state}
    end
  end
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
        case CommandResolver.find_bundle(command) do
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
    determine_inclusion(options)
    |> Repo.all
    |> Enum.map(&Enum.join(&1, ":"))
    |> Enum.sort
  end

  defp determine_inclusion(%{"disabled" => true}), do: Queries.Command.names_for(false)
  defp determine_inclusion(%{"all" => true}), do: Queries.Command.names
  defp determine_inclusion(_), do: Queries.Command.names_for(true)

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
