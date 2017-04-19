defmodule Cog.Template.Engine.Helpers do

  def json(thing),
    do: Poison.encode!(thing, pretty: true)

  def join(list, separator \\ ", "),
    do: Enum.join(list, separator)

end
