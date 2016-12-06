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

    operable:help ec2

  View documentation for a command:

    operable:help ec2:instance-show

  Test a pipeline with command output:

    operable:help --output ec2:instance-show | echo "Instance $instance_id is of type $instance_type"
  """

  @arguments "[<bundle> | <bundle:command>]"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:help allow"

  option "output", short: "o", type: "bool", required: false

  # When help is called with no arguments we return the list of installed bundles
  def handle_message(%{args: []} = req, state) do
    bundles = %{enabled: Repo.preload(Bundles.enabled, :bundle),
                disabled: Repo.preload(Bundles.highest_disabled_versions, :bundle)}
    {:reply, req.reply_to, "help-bundles", bundles, state}
  end
  # When called with arguments the user could be requesting help for either a bundle or
  # a command. We first do a lookup and then return the appropriate help.
  def handle_message(%{args: args, options: options} = req, state) do
    response = case lookup(args) do
      {:ok, %CommandVersion{bundle_version: %BundleVersion{config_file: %{"cog_bundle_version" => version}}} = command} when version < 4 ->
        command = Commands.preloads_for_help(command)
        {:ok, {:documentation, command.documentation}}
      {:ok, %CommandVersion{} = command} ->
        case {options["output"], command} do
          {true, command_version = %CommandVersion{output: %{"example" => nil}}} ->
            {:error, {:example_not_found, CommandVersion.full_name(command_version)}}
          {true, %CommandVersion{output: %{"example" => example}}} when not(is_nil(example)) ->
            {:ok, {:output, example}}
          {_, _} ->
            command = Commands.preloads_for_help(command)
            rendered = Cog.CommandVersionHelpView.render("command_version.json", %{command_version: command})
            {:ok, {:command, rendered}}
        end
      {:ok, %BundleVersion{config_file: config_file}} ->
        commands = Enum.map(config_file["commands"], fn({name, map}) -> Map.put(map, "name", name) end)
        {:ok, {:bundle, %{config_file | "commands" => commands}}}
      error ->
        error
    end

    case response do
      {:ok, {:bundle, bundle_config}} ->
        {:reply, req.reply_to, "help-bundle", bundle_config, state}
      {:ok, {:command, command}} ->
        {:reply, req.reply_to, "help-command", command, state}
      {:ok, {:documentation, documentation}} ->
        {:reply, req.reply_to, "help-command-documentation", %{documentation: documentation}, state}
      {:ok, {:output, output}} ->
        {:reply, req.reply_to, Poison.decode!(output), state}
      {:ok, body} ->
        {:reply, req.reply_to, body, state}
      {:error, error} ->
        {:error, req.reply_to, error_msg(error), state}
    end
  end

  # Note: We could do the command lookup first regardless of the presence of ':'
  # This would eliminate the second case statement but would also mean that commands
  # with the same name as bundles would take precedence.
  defp lookup(args) do
    cond do
      # If the first item in the arg list contains a ':' then we know the user is
      # requesting help for a command.
      String.contains?(hd(args), ":") ->
        lookup_command(args)
      # If any other item in the arg list has a ':' then the user left a space in
      # the bundle name which is invalid.
      Enum.any?(tl(args), &String.contains?(&1, ":")) ->
        bundle_name = Enum.join(args, " ")
                      |> String.split(":")
                      |> List.first()

        {:error, {:invalid_bundle, bundle_name}}
      # If there is no ':' then the user could be requesting help for a bundle or a command.
      # Bundles should take precedence over commands so we first see if a bundle exists.
      true ->
        case lookup_bundle(args) do
          {:ok, bundle} ->
            {:ok, bundle}
          {:error, bundle_error} ->
            # If there is no bundle then we do a command lookup
            case lookup_command(args) do
              {:ok, command} ->
                {:ok, command}
              # If the command isn't found we return :nothing_found instead of just
              # :command_not_found. Then we can give the user a more descriptive error.
              {:error, {:command_not_found, name}} ->
                {:error, {:nothing_found, bundle_error, {:command_not_found, name}}}
              # We could also get an ambiguous command error, so we just pass that along.
              error ->
                error
            end
      end
    end
  end

  defp lookup_command(args) when is_list(args) do
    # When requesting help for a command using the git style syntax we need to
    # join args with a '-'.
    Enum.join(args, "-")
    |> lookup_command()
  end
  defp lookup_command(name) do
    case Commands.with_status_by_any_name(name) do
      [] ->
        {:error, {:command_not_found, name}}
      [%CommandVersion{} = command] ->
        {:ok, command}
      commands ->
        # We preload here so we can go ahead and generate the fully qualified names for ambiguous commands.
        commands = Commands.preloads_for_help(commands)
        {:error, {:ambiguous, name, Enum.map(commands, &("#{&1.bundle_version.bundle.name}:#{&1.command.name}"))}}
    end
  end

  defp lookup_bundle([name]),
    do: lookup_bundle(name)
  defp lookup_bundle(args) when is_list(args),
    # Bundles cannot be specified with the special git style syntax. So if there
    # are spaces in the bundle name it is invalid.
    do: {:error, {:invalid_bundle, Enum.join(args, " ")}}
  defp lookup_bundle(name) do
    case Bundles.with_status_by_name(name) do
      nil ->
        {:error, {:bundle_not_found, name}}
      %BundleVersion{} = bundle ->
        {:ok, bundle}
    end
  end

  defp error_msg({:command_not_found, name}),
    do: "Command '#{name}' not found. Check the bundle and command name and try again."
  # We won't actually get this error since we always do a command lookup if the
  # bundle lookup fails, see lookup/1. But it is included for completeness.
  defp error_msg({:bundle_not_found, name}),
    do: "Bundle '#{name}' not found."
  defp error_msg({:nothing_found, {:bundle_not_found, name}, {:command_not_found, name}}),
    do: "Could not find a bundle or a command in any bundle with the name '#{name}'. Check the name and try again."
  defp error_msg({:nothing_found, {:invalid_bundle, _bundle_name}, {:command_not_found, name}}),
    do: "Could not find a command in any bundle with the name '#{name}'. Check the name and try again."
  defp error_msg({:invalid_bundle, name}),
    do: "Invalid bundle name '#{name}'. Check the name and try again."
  defp error_msg({:example_not_found, command}),
    do: "Command #{command} does not have an example included in its documentation"
  defp error_msg({:ambiguous, name, commands}) do
    """
    Multiple bundles contain a command with the name '#{name}'.
    Please specify which command by using the command's fully qualified name.

    #{Enum.sort(commands) |> Enum.join("\n")}
    """
  end

end
