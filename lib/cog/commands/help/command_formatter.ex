defmodule Cog.Commands.Help.CommandFormatter do
  alias Cog.Models.{BundleVersion, CommandOption, CommandOptionType, CommandVersion}

  def format(%CommandVersion{bundle_version: %BundleVersion{config_file: %{"cog_bundle_version" => version}}, documentation: documentation})
      when version < 4 do
    """
    ```
    #{String.trim_trailing(to_string(documentation))}
    ```
    """
  end

  def format(%CommandVersion{} = command_version) do
    body = command_version
    |> render_sections
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n\n")

    """
    ```
    #{body}
    ```
    """
  end

  defp render_sections(%CommandVersion{} = command_version) do
    [render_name(command_version),
     render_description(command_version),
     render_synopsis(command_version),
     render_required_options(command_version),
     render_options(command_version),
     render_subcommands(command_version),
     render_examples(command_version),
     render_notes(command_version),
     render_author(command_version),
     render_homepage(command_version)]
  end

  defp render_name(%CommandVersion{description: description} = command_version) do
    name = [CommandVersion.full_name(command_version), description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" - ")

    """
    NAME
      #{name}
    """
  end

  defp render_description(%CommandVersion{long_description: nil}),
    do: nil
  defp render_description(%CommandVersion{long_description: long_description}) do
    """
    DESCRIPTION
    #{indent(long_description)}
    """
  end

  defp render_synopsis(%CommandVersion{options: options, arguments: arguments} = command_version) do
    name = CommandVersion.full_name(command_version)
    options = render_synopsis_options(options)

    synopsis = [name, options, arguments]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")

    """
    SYNOPSIS
      #{synopsis}
    """
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

  defp render_required_options(%CommandVersion{options: options}) do
    required_options = Enum.filter(options, &(&1.required))

    case required_options do
      [] ->
        nil
      required_options ->
        required_options = required_options
        |> Enum.map(&render_option/1)
        |> Enum.join("\n\n")

        """
        REQUIRED OPTIONS
        #{indent(required_options)}
        """
    end
  end

  defp render_options(%CommandVersion{options: options}) do
    optional_options = Enum.reject(options, &(&1.required))
    
    case optional_options do
      [] ->
        nil
      optional_options ->
        optional_options = optional_options
        |> Enum.map(&render_option/1)
        |> Enum.join("\n\n")

        """
        OPTIONS
        #{indent(optional_options)}
        """
    end
  end

  defp render_option(%CommandOption{description: description} = command_option) do
    description = case description do
      nil ->
        nil
      description ->
        indent(description)
    end

    [render_flag(command_option), description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
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

  defp render_subcommands(%CommandVersion{subcommands: nil}),
    do: nil
  defp render_subcommands(%CommandVersion{subcommands: subcommands}) when map_size(subcommands) == 0,
    do: nil
  defp render_subcommands(%CommandVersion{subcommands: subcommands}) do
    padding = subcommands
    |> Map.keys
    |> Enum.map(&String.length/1)
    |> Enum.max

    subcommands = Enum.map_join(subcommands, "\n", fn {command, description} ->
      "#{String.pad_trailing(command, padding)}  #{description}"
    end)

    """
    SUBCOMMANDS
    #{indent(subcommands)}
    """
  end

  defp render_examples(%CommandVersion{examples: nil}),
    do: nil
  defp render_examples(%CommandVersion{examples: examples}) do
    """
    EXAMPLES
    #{indent(examples)}
    """
  end

  defp render_notes(%CommandVersion{notes: nil}),
    do: nil
  defp render_notes(%CommandVersion{notes: notes}) do
    """
    NOTES
    #{indent(notes)}
    """
  end

  defp render_author(%CommandVersion{bundle_version: %BundleVersion{author: nil}}),
    do: nil
  defp render_author(%CommandVersion{bundle_version: %BundleVersion{author: author}}) do
    """
    AUTHOR
    #{indent(author)}
    """
  end

  defp render_homepage(%CommandVersion{bundle_version: %BundleVersion{homepage: nil}}),
    do: nil
  defp render_homepage(%CommandVersion{bundle_version: %BundleVersion{homepage: homepage}}) do
    """
    HOMEPAGE
    #{indent(homepage)}
    """
  end

  defp indent(string) do
    string
    |> String.split("\n")
    |> Enum.map(&("  " <> &1))
    |> Enum.join("\n")
  end
end
