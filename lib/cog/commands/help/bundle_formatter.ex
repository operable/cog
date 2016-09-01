defmodule Cog.Commands.Help.BundleFormatter do
  alias Cog.Models.{Bundle, BundleVersion, CommandVersion}

  def format(%BundleVersion{} = bundle_version) do
    body = bundle_version
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

  defp render_sections(%BundleVersion{} = bundle_version) do
    [render_name(bundle_version),
     render_description(bundle_version),
     render_commands(bundle_version),
     render_author(bundle_version),
     render_homepage(bundle_version)]
  end

  defp render_name(%BundleVersion{bundle: %Bundle{name: name}, description: description}) do
    name = [name, description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" - ")

    """
    NAME
      #{name}
    """
  end

  defp render_description(%BundleVersion{long_description: nil}),
    do: nil
  defp render_description(%BundleVersion{long_description: long_description}) do
    """
    DESCRIPTION
    #{indent(long_description)}
    """
  end

  defp render_commands(%BundleVersion{commands: []}),
    do: nil
  defp render_commands(%BundleVersion{commands: commands}) do
    command_bullets = commands
    |> Enum.map(&render_command/1)
    |> Enum.map(&("* " <> &1))
    |> Enum.join("\n")

    """
    COMMANDS
    #{indent(command_bullets)}

      For details about a specific command, you can use `operable:help <command>`, 
      for example `operable:help mist:ec2-find`.
    """
  end

  defp render_command(%CommandVersion{description: description} = command_version) do
    name = CommandVersion.full_name(command_version)

    [name, description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" - ")
  end

  defp render_author(%BundleVersion{author: nil}),
    do: nil
  defp render_author(%BundleVersion{author: author}) do
    """
    AUTHOR
    #{indent(author)}
    """
  end

  defp render_homepage(%BundleVersion{homepage: nil}),
    do: nil
  defp render_homepage(%BundleVersion{homepage: homepage}) do
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
