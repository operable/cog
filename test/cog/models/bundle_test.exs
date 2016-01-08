defmodule Cog.Models.BundleTest do
  use Cog.ModelCase
  alias Cog.Models.Bundle

  @valid_attrs %{name: "test_bundle", config_file: %{}, manifest_file: %{}}

  test "bundle names must be made up of word characters and dashes" do
    invalid_attrs = Map.merge(@valid_attrs, %{name: "weird:name"})
    bundle = Bundle.changeset(%Bundle{}, invalid_attrs)

    assert %{errors: [name: "has invalid format"]} = bundle
  end
end
