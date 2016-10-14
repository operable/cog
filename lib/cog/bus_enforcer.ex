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

  @internal_mq_username Cog.Util.Misc.internal_mq_username

  def connect_allowed?(client, password) do
    username = mqtt_client(client, :username)
    internal_password = Application.fetch_env!(:cog, :message_queue_password)

    case {username, password} do
      {@internal_mq_username, ^internal_password} ->
        true
      {:undefined, _} ->
        false
      {_, :undefined} ->
        false
      _ ->
        case Repo.one(Queries.Relay.for_id(username)) do
          nil ->
            addr = format_address(mqtt_client(client, :peername))
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

  def subscription_allowed?(client, topic) do
    case mqtt_client(client, :username) do
      @internal_mq_username ->
        true
      :undefined ->
        false
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

  defp format_address({addr, _}) do
    addr = Tuple.to_list(addr)
    if length(addr) == 4 do
      Enum.join(addr, ".")
    else
      Enum.join(addr, ":")
    end
  end

end
