defmodule Cog.Commands.Help.BundlesFormatter do
  alias Cog.Models.{Bundle, BundleVersion}

  def format(grouped_bundles) do
    body = grouped_bundles
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

  defp render_sections(%{enabled: enabled, disabled: disabled}) do
    [render_enabled(enabled),
     render_disabled(disabled),
     render_learn_more] 
  end

  defp render_enabled([]),
    do: nil
  defp render_enabled(bundles) do
    bullets = bundles
    |> Enum.map(&render_bundle/1)
    |> Enum.map(&("* " <> &1))
    |> Enum.join("\n")

    """
    ENABLED BUNDLES
    #{indent(bullets)}
    """
  end

  defp render_disabled([]),
    do: nil
  defp render_disabled(bundles) do
    bullets = bundles
    |> Enum.map(&render_bundle/1)
    |> Enum.map(&("* " <> &1))
    |> Enum.join("\n")

    """
    DISABLED BUNDLES
    #{indent(bullets)}
    """
  end

  defp render_bundle(%BundleVersion{bundle: %Bundle{name: name}, description: description}) do
    [name, description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" - ")
  end

  defp render_learn_more do
    """
    To learn more about a specific bundle and the commands available within it,
    you can use `operable:help <bundle>`.
    """
  end

  defp indent(string) do
    string
    |> String.split("\n")
    |> Enum.map(&("  " <> &1))
    |> Enum.join("\n")
  end
end
