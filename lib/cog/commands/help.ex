defmodule Cog.Commands.Help do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.embedded_bundle

  use Cog.Models
  alias Cog.Repo
  alias Cog.Queries

  @moduledoc """
  Prints help documentation for all commands.

  USAGE
    help [FLAGS] <command>

  ARGS
    command  prints long form documentation

  FLAGS
    -a, --all       Lists all enabled and disabled commands
    -d, --disabled  Lists all disabled commands

  EXAMPLES
    help
    > operable:alias
      operable:bundle
      operable:echo
      operable:filter
      operable:group
      operable:help
      operable:max
      operable:min
      operable:permissions
      operable:raw
      operable:relay
      operable:relay-group
      operable:role
      operable:rules
      operable:seed
      operable:sleep
      operable:sort
      operable:sum
      operable:table
      operable:unique
      operable:wc
      operable:which
  """

  rule "when command is #{Cog.embedded_bundle}:help allow"

  option "all",      short: "a", type: "bool", required: false
  option "disabled", short: "d", type: "bool", required: false

  def handle_message(%{args: [], options: options} = req, state) do
    commands = Repo.all(find_commands_query(options))
    {:reply, req.reply_to, "help", commands, state}
  end

  def handle_message(%{args: [command]} = req, state) do
    case Repo.all(find_command_query(command)) do
      [%{documentation: documentation} = command] when is_binary(documentation) ->
        {:reply, req.reply_to, "help-command", [command], state}
      [%{documentation: nil} = command] ->
        name = Command.full_name(command)
        {:error, req.reply_to, "Command #{inspect name} does not have any documentation", state}
      [] ->
        {:error, req.reply_to, "Command #{inspect command} does not exist", state}
      commands when is_list(commands) ->
        names = Enum.map_join(commands, "\n", &Command.full_name/1)

        message = """
        Multiple commands found for command #{inspect command}. Please choose one:

        #{names}
        """

        {:error, req.reply_to, message, state}
    end
  end

  def handle_message(req, state) do
    {:reply, req.reply_to, "usage", %{usage: @moduledoc}, state}
  end

  defp find_commands_query(%{"all" => true}) do
    Command
    |> Queries.Command.sorted_by_qualified_name
  end

  defp find_commands_query(%{"disabled" => true}) do
    Command
    |> Queries.Command.disabled
    |> Queries.Command.sorted_by_qualified_name
  end

  defp find_commands_query(%{}) do
    Command
    |> Queries.Command.enabled
    |> Queries.Command.sorted_by_qualified_name
  end

  defp find_command_query(command) do
    Queries.Command.by_any_name(command)
  end
end
