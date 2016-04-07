defmodule Cog.BusEnforcer do
  @moduledoc """
  Checks credentials for connecting MQTT clients and
  enforces subscription ACLs for Relays
  """

  require Logger
  require Record

  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Models.Relay
  alias Cog.Passwords

  Record.defrecord :mqtt_client, Record.extract(:mqtt_client, from_lib: "emqttd/include/emqttd.hrl")

  def connect_allowed?(client, password) do
    case mqtt_client(client, :peername) do
      {{127, 0, 0, 1}, _} ->
        true
      _ ->
        validate_creds(client, password)
    end
  end

  def subscription_allowed?(client, topic) do
    case mqtt_client(client, :username) do
      :undefined ->
        case mqtt_client(client, :peername) do
          {{127, 0, 0, 1}, _} ->
            true
          _ ->
            false
        end
      username ->
        case Repo.exists?(Relay, username) do
          false ->
            false
          true ->
            relays_prefix = "bot/relays/#{username}"
            commands_prefix = "/bot/commands/#{username}"
            String.starts_with?(topic, relays_prefix) or
              String.starts_with?(topic, commands_prefix)
        end
    end
  end

  defp validate_creds(client, password) do
    username = mqtt_client(client, :username)
    addr = format_address(mqtt_client(client, :peername))
    if username == :undefined or password == :undefined do
      false
    else
      case Repo.one(Queries.Relay.for_id(username)) do
        nil ->
          Logger.info("Denied connect attempt for unknown client #{username} from #{addr}")
          false
        relay ->
          if Passwords.matches?(password, relay.token_digest) do
            Logger.info("Allowed connection for Relay #{username}")
            true
          else
            Logger.info("Denied connection for Relay #{username} (bad token)")
            false
          end
      end
    end
  end

  defp format_address({addr, _}) do
    addr = Tuple.to_list(addr)
    if length(addr) == 4 do
      Enum.join(addr, ".")
    else
      Enum.join(addr, ":")
    end
  end

end
