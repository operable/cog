defmodule Cog.Command.RequestTest do
  use ExUnit.Case, async: true

  alias Cog.Command.Request

  setup do
    config_dir = unique_temporary_dir

    old_root = Application.get_env(:spanner, :command_config_root)
    Application.put_env(:spanner, :command_config_root, config_dir)
    on_exit(fn() -> Application.put_env(:spanner, :command_config_root, old_root) end)

    {:ok, %{dir: config_dir}}
  end

  test "external config is properly consumed when present", %{dir: dir} do
    config = """
    ---
    SOOPER_SEEKRIT: "COG_4_LIFE"
    """
    write_bundle_config_file(dir, "test-bundle", config)

    input = %{"room" => "my_room",
              "requestor" => "me",
              "command" => "test-bundle:test-command",
              "reply_to" => "/somewhere/interesting"}

    request = Request.decode!(input)
    assert %Request{command_config: %{"SOOPER_SEEKRIT" => "COG_4_LIFE"}} = request
  end

  defp unique_temporary_dir do
    path = Path.join(System.tmp_dir!, "RequestTest#{:erlang.monotonic_time}")
    File.mkdir_p!(path)
    path
  end

  defp write_bundle_config_file(config_root, bundle_name, config_content) do
    bundle_path = Path.join(config_root, bundle_name)
    File.mkdir_p!(bundle_path)
    File.write!(Path.join(bundle_path, "config.yaml"),
                config_content)
  end
end
