defmodule Cog.Formatters.Slack do
  alias Cog.Formatters.Monospace
  alias Cog.Formatters.Table

  def table(data) do
    Table.format(data)
  end

  def monospace(string) do
    Monospace.format(string)
  end
end
