defmodule Cog.Models.BundleVersionRepoTest do
  use Cog.ModelCase, async: false

  alias Cog.Repository.Bundles

  test "permissions are version-specific" do
    {:ok, v1} = Bundles.install(%{"name" => "foo",
                                  "version" => "1.0.0",
                                  "config_file" => %{"name" => "foo",
                                                     "version" => "1.0.0",
                                                     "permissions" => ["foo:a", "foo:b", "foo:c"]}})

    {:ok, v2} = Bundles.install(%{"name" => "foo",
                                  "version" => "2.0.0",
                                  "config_file" => %{"name" => "foo",
                                                     "version" => "2.0.0",
                                                     "permissions" => ["foo:c", "foo:d"]}})

    assert ["a", "b", "c"] = sorted_permission_names(v1)
    assert ["c", "d"] = sorted_permission_names(v2)
  end

  defp sorted_permission_names(version) do
    Cog.Repo.preload(version, :permissions).permissions
    |> Enum.map(&(&1.name))
    |> Enum.sort
  end

end
