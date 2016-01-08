defmodule Cog.Formatters.Text do
  def format(lines) do
    Enum.join(lines, "\n")
  end
end
