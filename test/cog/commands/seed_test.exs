defmodule Cog.Commands.SeedTest do
  use Cog.EmbeddedCommandCase

  test "basic seeding" do
    {:ok, result} = execute_embedded_command("seed", args: [~s([{"a": 1}, {"a": 3}, {"a": 2}])])
    assert_body(result, [%{"a" => 1},
                         %{"a" => 3},
                         %{"a" => 2}])
    refute_template(result)
  end

end
