defmodule Cog.Command.Service.TokensTest do
  use ExUnit.Case

  alias Cog.Command.Service.Tokens
  alias Cog.ServiceHelpers

  test "a token is registered to the process that asked for it" do
    {pid, token} = ServiceHelpers.spawn_fake_executor
    assert ^pid = Tokens.process_for_token(token)
  end

  test "a token is invalidated when the consumer process terminates normally" do
    {pid, token} = ServiceHelpers.spawn_fake_executor

    send(pid, :exit_normally)
    :timer.sleep(500)

    assert {:error, :unknown_token} = Tokens.process_for_token(token)
  end

  test "a token is invalidated when the consumer process crashes" do
    {pid, token} = ServiceHelpers.spawn_fake_executor

    send(pid, :crash)
    :timer.sleep(500)

    assert {:error, :unknown_token} = Tokens.process_for_token(token)
  end
end
