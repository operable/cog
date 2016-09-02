 defmodule Cog.Commands.EchoTest do
  use Cog.EmbeddedCommandCase

  test "Repeats whatever it is passed" do
    {:ok, result} = execute_embedded_command("echo", args: ["this", "is", "nifty"])
    assert_body(result, %{"body" => ["this is nifty"]})
    refute_template(result)
  end

end
