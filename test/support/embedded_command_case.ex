defmodule Cog.EmbeddedCommandCase do
  use ExUnit.CaseTemplate, async: false

  alias Carrier.Messaging.Connection
  alias Cog.Messages.Command
  alias Cog.Messages.CommandResponse

  require Logger

  using do
    quote do
      import unquote(__MODULE__)

      # Was wanting this so we could run
      #
      #    mix test --only=embedded_command
      #
      # but I'm failing to connect to emqttd for some reason. If I run
      # like
      #
      #    mix test test/path/to/test.exs
      #
      # the tests work, though... probably need some additional
      # startup logic here

      # @moduletag :embedded_command
    end
  end

  ########################################################################
  # Assertions

  def assert_body(%CommandResponse{}=response, expected),
    do: assert %CommandResponse{body: ^expected} = response

  def refute_template(%CommandResponse{}=response),
    do: assert %CommandResponse{template: nil} = response

  ########################################################################

  def execute_embedded_command(embedded_command_name, details) do
    {:ok, conn} = Connection.connect

    try do
      reply   = reply_to(embedded_command_name)
      command = command(embedded_command_name, reply, details)
      topic   = command_topic(embedded_command_name)

      Connection.subscribe(conn, reply)
      Connection.publish(conn, command, routed_by: topic)

      receive do
        {:publish, ^reply, message} ->
          {:ok, CommandResponse.decode!(message)}
      after 5000 ->
          {:error, :timeout}
      end
    after
      Connection.disconnect(conn)
    end
  end

  ########################################################################
  # Internal

  defp command(command_name, reply_to, details) do
    %Command{invocation_id:   Cog.Events.Util.unique_id,
             command:         command_name,
             args:            Keyword.get(details, :args, []),
             options:         Keyword.get(details, :opts, %{}),
             cog_env:         Keyword.get(details, :cog_env, %{}),
             invocation_step: Keyword.get(details, :invocation_step, "last"),
             reply_to:        reply_to,
             requestor:       Keyword.get(details, :requestor, default_requestor),
             room:            Keyword.get(details, :room, default_room),
             service_token:   Keyword.get(details, :service_token, "XXXXX"),
             services_root:   Cog.ServiceEndpoint.public_url,
             user:            Keyword.get(details, :user, %{})}
  end

  defp default_requestor do
    %Cog.Chat.User{id: "1234",
                   provider: "test",
                   first_name: "Cog",
                   last_name: "McCog",
                   handle: "cog"}
  end

  defp default_room do
    %Cog.Chat.Room{id: "myroomID",
                   name: "myroom",
                   provider: "test",
                   is_dm: false}
  end

  defp command_topic(command_name),
    do: "/bot/commands/#{Cog.Config.embedded_relay}/#{Cog.Util.Misc.embedded_bundle}/#{command_name}"

  defp reply_to(command_name),
    do: "/test/#{Cog.Events.Util.unique_id}/#{command_name}"

end
