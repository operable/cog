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

  option "all", type: "bool", required: false
  option "disabled", type: "bool", required: false

  def handle_message(%{args: [], options: options, reply_to: reply_to}, state) do
    case commands(options) do
      # We do not allow embedded commands to be disabled, so this
      # would only happen for looking for disabled commands
      [] -> {:reply, reply_to, "There are no disabled commands.", state}
      commands -> {:reply, reply_to, "help", %{"commands" => commands}, state}
    end
  end
  def handle_message(%{args: [command], reply_to: reply_to}, state) when is_binary(command) do
    case get_docs(command) do
      {:ok, docs} ->
        {:reply, reply_to, "help", docs, state}
      {:error, msg} ->
        {:error, reply_to, msg, state}
    end
  end
  def handle_message(%{reply_to: reply_to}, state),
    do: {:error, reply_to, "Call this command with either no arguments or 1 string argument only", state}

  defp get_docs(command_name) do
    case Repo.all(Cog.Queries.Command.by_any_name(command_name)) do
      [] ->
        {:error, "No command `#{command_name}` found"}
      [command] ->
        case command.documentation do
          "" ->
            {:error, "No documentation for command '#{qualified_name(command)}' found."}
          docs ->
            {:ok, %{"command" => qualified_name(command), "documentation" => docs}}
        end
      commands when is_list(commands) ->
        # More than one; ambiguous!
        all_names = commands
        |> Enum.map(&qualified_name/1)
        |> Enum.map(&("* #{&1}\n"))
        message = """

                  Multiple commands found for `#{command_name}`; please choose one:

                  #{all_names}
                  """
        {:error, message}
    end
  end

  defp qualified_name(command),
    do: "#{command.bundle.name}:#{command.name}"

  defp commands(options) do
    determine_inclusion(options)
    |> Repo.all
    |> Enum.map(&Enum.join(&1, ":"))
    |> Enum.sort
  end

  defp determine_inclusion(%{"disabled" => true}), do: Queries.Command.names_for(false)
  defp determine_inclusion(%{"all" => true}), do: Queries.Command.names
  defp determine_inclusion(_), do: Queries.Command.names_for(true)

end
