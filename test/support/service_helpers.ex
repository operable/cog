defmodule Cog.ServiceHelpers do
  import ExUnit.Assertions
  alias Cog.Command.Service

  # Creates a process that acts as an executor, sending its
  # pid and token back to the test case proecss. From the
  # tests you can then send `:exit_normally` or `:crash` to
  # cause a successful exit or process crash respectively.
  def spawn_fake_executor do
    caller = self()

    pid = spawn(fn ->
      token = Service.Tokens.new
      send(caller, {:token, token, self()})

      receive do
        :exit_normally ->
          :ok
        :crash ->
          raise "BOOM!"
      after
        2000 ->
          flunk "Timeout waiting to receive instruction in token consumer!"
      end
    end)

    receive do
      {:token, token, ^pid} ->
        {pid, token}
    after
      1000 ->
        flunk "Timeout waiting to receive token!"
    end
  end
end
