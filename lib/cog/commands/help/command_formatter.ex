defmodule Cog.Commands.Help.CommandFormatter do
  alias Cog.Models.{BundleVersion, CommandOption, CommandOptionType, CommandVersion}

  def render_synopsis(%CommandVersion{options: options, arguments: arguments} = command_version) do
    name = CommandVersion.full_name(command_version)
    options = render_synopsis_options(options)

    [name, options, arguments]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  def render_required_options(%CommandVersion{options: options}) do
    options
    |> Enum.filter(&(&1.required))
    |> Enum.map(&render_option/1)
  end

  def render_options(%CommandVersion{options: options}) do
    options
    |> Enum.reject(&(&1.required))
    |> Enum.map(&render_option/1)
  end

  def render_subcommands(%CommandVersion{subcommands: nil}),
    do: []
  def render_subcommands(%CommandVersion{subcommands: subcommands}) do
    Enum.map(subcommands, fn {command, description} ->
      %{command: command,
        description: description}
    end)
  end

  defp render_synopsis_options([]),
    do: nil
  defp render_synopsis_options(options) do
    required_options = Enum.filter(options, &(&1.required))
    optional_options = Enum.reject(options, &(&1.required))

    required_options = Enum.map(required_options, &render_synopsis_option/1)

    optional_options = case optional_options do
      optional_options when length(optional_options) > 5 ->
        "[options]"
      optional_options ->
        Enum.map(optional_options, &render_synopsis_option/1)
    end

    [required_options, optional_options]
    |> List.flatten
    |> Enum.join(" ")
  end

  defp render_synopsis_option(%CommandOption{required: required} = command_option) do
    flag = render_flag(%{command_option | short_flag: nil})

    case required do
      true ->
        flag
      false ->
        "[#{flag}]"
    end
  end

  defp render_option(%CommandOption{description: description} = command_option) do
    %{flag: render_flag(command_option),
      description: description}
  end

  defp render_flag(command_option) do
    [render_short_flag(command_option), render_long_flag(command_option)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp render_short_flag(%CommandOption{short_flag: nil}),
    do: nil
  defp render_short_flag(%CommandOption{short_flag: short_flag, option_type: %CommandOptionType{name: "bool"}}),
    do: "-#{short_flag}"
  defp render_short_flag(%CommandOption{short_flag: short_flag, name: name}),
    do: "-#{short_flag} <#{name}>"

  defp render_long_flag(%CommandOption{long_flag: long_flag, option_type: %CommandOptionType{name: "bool"}}),
    do: "--#{long_flag}"
  defp render_long_flag(%CommandOption{long_flag: long_flag, name: name}),
    do: "--#{long_flag} <#{name}>"
end
