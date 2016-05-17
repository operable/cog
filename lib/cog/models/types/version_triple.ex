defmodule Cog.Models.Types.VersionTriple do


  @version_separator "."


  # type should output the name of the db type
  # cast should receive any type and output your custom Ecto type
  # load should receive the db type and output your custom Ecto type
  # dump should receive your custom Ecto type and output the db type

  @behaviour Ecto.Type
  def type,
    do: :array

  def cast(version_string) when is_binary(version_string) do
    case version_string
    |> String.split(@version_separator)
    |> Enum.map(&Integer.parse/1) do
      [{_major, ""}, {_minor, ""}, {_patch, ""}] ->
        #{:ok, [major, minor, patch]}
        {:ok, version_string}
      _ ->
        :error
    end
  end
  def cast([major, minor, patch]=version) when is_integer(major) and
                                               is_integer(minor) and
                                               is_integer(patch) do
    {:ok, Enum.join(version, @version_separator)}
  end
  def cast(_),
    do: :error

  def load(version) when is_list(version),
    do: {:ok, Enum.join(version, @version_separator)}

#  def dump([_major, _minor, _patch]=version),
#    do: {:ok, version}
  def dump(version) when is_binary(version) do
    [{major, ""}, {minor, ""}, {patch, ""}] = version
    |> String.split(@version_separator)
    |> Enum.map(&Integer.parse/1)

    {:ok, [major, minor, patch]}
  end
  def dump(_),
    do: :error


  # @behaviour Ecto.Type

  # def type(),
  #   do: __MODULE__

  # def cast(text),
  #   do: Version.parse(text)

  # def dump(%Version{major: major, minor: minor, patch: patch}),
  #   do: {:ok, [major, minor, patch]}
  # def dump(_),
  #   do: :error

  # def load([major, minor, patch]),
  #   do: {:ok, %Version{major: major, minor: minor, patch: patch}}
  # def load(%Ecto.Query.Tagged{type: :version_triple, value: value}),
  #   do: load(value)
  # def load(_),
  #   do: :error

end
