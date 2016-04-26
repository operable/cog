defmodule Cog.Command.Service.TokensTest do
  use ExUnit.Case

  alias Cog.Command.Service.Tokens

  test "a token is registered to the process that asked for it" do
    {pid, token} = fake_executor
    assert ^pid = Tokens.process_for_token(token)
  end

  test "a token is invalidated when the consumer process terminates normally" do
    {pid, token} = fake_executor

    send(pid, :exit_normally)
    :timer.sleep(500)

    assert {:error, :unknown_token} = Tokens.process_for_token(token)
  end

  test "a token is invalidated when the consumer process crashes" do
    {pid, token} = fake_executor

    send(pid, :crash)
    :timer.sleep(500)

    assert {:error, :unknown_token} = Tokens.process_for_token(token)
  end

  ########################################################################

  defp fake_executor do
    caller = self()
    pid = spawn(fn() ->
      token = Tokens.new
      send(caller, {:token, token, self()})
      receive do
        :exit_normally ->
          :ok
        :crash ->
          raise "BOOM!"
      after 2000 ->
          flunk "Timeout waiting to receive instruction in token consumer!"
      end
    end)

    receive do
      {:token, token, ^pid} ->
        {pid, token}
    after 1000 ->
        flunk "Timeout waiting to receive token!"
    end
  end
end
