defmodule Cog.Commands.Help.CommandFormatter do
  alias Cog.Models.{BundleVersion, CommandOption, CommandVersion}

  def format(%CommandVersion{bundle_version: %BundleVersion{config_file: %{"cog_bundle_version" => version}}, documentation: documentation})
      when version < 4 do
    """
    ```
    #{String.trim_trailing(documentation)}
    ```
    """
  end

  def format(%CommandVersion{} = command_version) do
    body = command_version
    |> render_sections
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> String.trim_trailing

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
    options
    |> Enum.sort_by(&(&1.required))
    |> Enum.reverse
    |> Enum.map(&render_synopsis_option/1)
    |> Enum.join(" ")
  end

  defp render_synopsis_option(%CommandOption{name: name, long_flag: long_flag, required: required}) do
    option = "--#{long_flag} <#{name}>"

    case required do
      true ->
        option
      false ->
        "[#{option}]"
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
        |> Enum.join("\n")

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
        |> Enum.join("\n")

        """
        OPTIONS
        #{indent(optional_options)}
        """
    end
  end

  defp render_option(%CommandOption{name: name, long_flag: long_flag, desc: desc}) do
    desc = case desc do
      nil ->
        nil
      desc ->
        indent(desc)
    end

    ["--#{long_flag} <#{name}>", desc]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
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
