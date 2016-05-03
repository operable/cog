defmodule Cog.Commands.Relay.Update do
  @moduledoc """
  Updates relay name and/or description.

  Usage:
  relay update <relay name> [-n <name>] [-d <description>]

  Flags:
  -n, --name           Update the relay's name
  -d, --description    Update the relay's description
  """

  @doc """
  Updates relays. Accepts a cog request and args. Returns either
  a success tuple or an error.
  """
  @spec update_relay(%Cog.Command.Request{}, List.t) :: {:ok, String.t, Map.t} | {:error, any()}
  def update_relay(_req, _args) do
  end
end
