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

  def cast(num) when is_integer(num) or is_float(num),
    do: cast(to_string(num))
  def cast(text) when is_binary(text) do
    cond do
      Regex.match?(~r/\A\d+\z/, text) ->
        # Just a major version; e.g. "1" == "1.0.0"
        Version.parse(text <> ".0.0")
      Regex.match?(~r/\A\d+\.\d+\z/, text) ->
        # Major and minor version; e.g. "1.0" == "1.0.0"
        Version.parse(text <> ".0")
      true ->
        # Treat it like semver
        Version.parse(text)
    end
  end
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
