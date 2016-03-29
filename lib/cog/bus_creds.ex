defmodule Cog.BusCredentials do
  @moduledoc """
  Checks credentials for connecting MQTT clients and
  enforces subscription ACLs for Relays
  """

  require Logger
  require Record

  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Passwords

  Record.defrecord :mqtt_client, Record.extract(:mqtt_client, from_lib: "emqttd/include/emqttd.hrl")

  def connect_allowed?(client, password) do
    case mqtt_client(client, :peername) do
      {{127, 0, 0, 1}, _} ->
        true
      _ ->
        validate_creds(mqtt_client(client, :username), password)
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
        case Queries.Relays.exists?(username) do
          false ->
            false
          true ->
            prefix = "bot/relays/#{username}"
            String.starts_with?(topic, prefix)
        end
    end
  end

  defp validate_creds(username, password) do
    if username == :undefined or password == :undefined do
      false
    else
      case Repo.one(Queries.Relay.from_id(username)) do
        nil ->
          false
        relay ->
          Passwords.matches?(password, relay.token)
      end
    end
  end

end
