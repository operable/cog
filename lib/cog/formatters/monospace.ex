defmodule Cog.Formatters.Monospace do
  def format(string) do
    "```#{string}```"
  end
end
