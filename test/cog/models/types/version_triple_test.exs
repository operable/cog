defmodule Cog.Models.Types.VersionTripleTest do
  use ExUnit.Case, async: true

  alias Cog.Models.Types.VersionTriple

  test "things that are not strictly semver still cast" do
    assert_version_casts_to(1, "1.0.0")
    assert_version_casts_to(1.0, "1.0.0")
    assert_version_casts_to("1", "1.0.0")
    assert_version_casts_to("1.0", "1.0.0")
    assert_version_casts_to("1.0.0", "1.0.0")
  end

  test "prerelease metadata are not allowed" do
    assert :error = VersionTriple.cast("1.0.0-pre1")
  end

  test "build metadata are not allowed" do
    assert :error = VersionTriple.cast("1.0.0+0123")
  end

  test "prerelease and build metadata together are not allowed" do
    assert :error = VersionTriple.cast("1.0.0-pre1+0123")
  end

  ########################################################################

  defp assert_version_casts_to(input, expected_string),
    do: assert Version.parse(expected_string) == VersionTriple.cast(input)

end
