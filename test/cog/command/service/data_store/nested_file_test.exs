defmodule Cog.Command.Service.DataStore.NestedFile.Test do
  use ExUnit.Case
  alias Cog.Command.Service.DataStore.NestedFile

  doctest Cog.Command.Service.DataStore.NestedFile

  setup do
    base_paths = [
      Application.get_env(:cog, Cog.Command.Service)[:data_path],
      "test", "nested_file"
    ]

    {:ok, content: "my test data", base_paths: base_paths}
  end

  test "save and delete content to file under split path", %{base_paths: base_paths, content: content} do
    path = Path.join(base_paths ++ ["te/st/fi/testfile01.data"])
    key = "testfile01"

    assert {:ok, ^content} = NestedFile.replace(base_paths, key, content)
    assert File.exists?(path)

    assert :ok = NestedFile.delete(base_paths, key)
    refute File.exists?(path)
  end

  test "sanitize filename from key", %{base_paths: base_paths, content: content} do
    path = Path.join(base_paths ++ ["te/ca/te/tecatetcpasswd.data"])
    key = "te../;cat /etc/passwd"

    assert {:ok, ^content} = NestedFile.replace(base_paths, key, "my test data")
    assert File.exists?(path)
    assert :ok = NestedFile.delete(base_paths, key)
  end

  test "return data from file for key", %{base_paths: base_paths, content: content} do
    key = "testfile02"
    NestedFile.replace(base_paths, key, content, "test")
    assert {:ok, ^content} = NestedFile.fetch(base_paths, key, "test")
  end
end
