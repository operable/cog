defmodule Cog.Models.Types.VersionTriple do

  # Just copying this doc here for reference, since I can never keep
  # them straight
  #
  # type should output the name of the db type
  # cast should receive any type and output your custom Ecto type
  # load should receive the db type and output your custom Ecto type
  # dump should receive your custom Ecto type and output the db type

  @behaviour Ecto.Type

  def type,
    do: :array

  def cast(text) when is_binary(text),
    do: Version.parse(text)
  def cast(%Version{}=v),
    do: {:ok, v}
  def cast(_),
    do: :error

  def dump(%Version{major: major, minor: minor, patch: patch}),
    do: {:ok, [major, minor, patch]}
  def dump(_),
    do: :error

  def load([major, minor, patch]),
    do: Version.parse("#{major}.#{minor}.#{patch}")
  def load(_),
    do: :error

end
