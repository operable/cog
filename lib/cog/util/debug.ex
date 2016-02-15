defmodule Cog.Util.Debug do

  @moduledoc """
  Debug helper module. For times when debugging via IO.puts is the only way.
  """

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: [debug: 1]
    end
  end

  defmacro debug(msg) do
    source_file = format_file_name(__CALLER__.file)
    line = __CALLER__.line
    quote do
      IO.puts("+--- DEBUG ---+\n[#{unquote(source_file)}:#{unquote(line)}] #{inspect unquote(msg)}\n" <>
              "+--- DEBUG ---+")
    end
  end


  defp format_file_name(name) do
    parts = String.split(name, "/")
    format_file_name(parts, false)
  end

  defp format_file_name(["lib"|_]=parts, false) do
    format_file_name(parts, true)
  end
  defp format_file_name([_|t], false) do
    format_file_name(t, false)
  end
  defp format_file_name(parts, true) do
    Enum.join(parts, "/")
  end

end
