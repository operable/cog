defmodule Cog.Command.Pipeline.Initializer do
  @moduledoc """
  Listens for pipeline requests, triggering the execution of those
  pipelines.

  Additionalaly, tracks the history of requests being made, thus
  providing a "history" function, whereby a user may re-run the last
  request they made.
  """

  require Logger

  alias Carrier.Messaging.Connection
  alias Cog.Command.ReplyHelper
  alias Cog.Command.Pipeline.ExecutorSup
  alias Cog.Repository.Users
  alias Cog.Repository.ChatHandles
  alias Cog.Passwords

  defstruct mq_conn: nil, history: %{}, history_token: ""

  use GenServer

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    cp = Application.get_env(:cog, :command_prefix)
    {:ok, conn} = Connection.connect()
    Connection.subscribe(conn, "/bot/commands")
    Logger.info("Ready.")
    {:ok, %__MODULE__{mq_conn: conn, history_token: "#{cp}#{cp}"}}
  end

  def handle_info({:publish, "/bot/commands", message}, state) do
    payload = Cog.Messages.AdapterRequest.decode!(message)
    # Only self register when the feature is enabled via config
    # and the incoming request is from Slack.
    #
    # TODO: should only do this if the adapter is a chat adapter
    self_register_flag = Application.get_env(:cog, :self_registration, false) and payload.adapter == "slack"
    case self_register_user(payload, self_register_flag, state) do
      :ok ->
        # TODO: should only do history check if the adapter is a chat
        # adapter, too
        case check_history(payload, state) do
          {true, payload, state} ->
            {:ok, _} = ExecutorSup.run(payload)
            {:noreply, state}
          {false, state} ->
            {:noreply, state}
        end
      :error ->
        {:noreply, state}
    end
  end

  def handle_info(_, state),
    do: {:noreply, state}

  defp check_history(payload, state) do
    uid = payload.sender.id
    text = String.strip(payload.text)
    if text == state.history_token do
      retrieve_last(uid, payload, state)
    else
      {true, payload, put_in_history(uid, text, state)}
    end
  end

  defp put_in_history(uid, text, %__MODULE__{history: history}=state),
    do: %{state | history: Map.put(history, uid, text)}

  defp retrieve_last(uid, payload, %__MODULE__{history: history}=state) do
    case Map.get(history, uid) do
      nil ->
        response = %Cog.Messages.SendMessage{response: "No history available.",
                                             room: payload.room}

        Connection.publish(state.mq_conn, response, routed_by: payload.reply)

        {false, state}
      previous ->
        {true, %{payload | text: previous}, state}
    end
  end

  defp self_register_user(request, true, state) do
    sender = request.sender
    case Users.by_chat_handle(sender.handle, request.adapter) do
      {:ok, _} ->
        :ok
      {:error, :not_found} ->
        case find_available_username(sender.handle) do
          {:ok, username} ->
            case Users.new(%{"username" => username,
                             "first_name" => sender.first_name,
                             "last_name" => sender.last_name,
                             "email_address" => sender.email,
                             "password" => Passwords.generate_password(12)}) do
              {:ok, user} ->
                case ChatHandles.set_handle(user, request.adapter, sender.handle) do
                  {:ok, _} ->
                    self_registration_success(user, request, state)
                    :ok
                  error ->
                    Logger.error("Failed to auto-register user '#{sender.handle}': #{inspect error}")
                    self_registration_failed(request, state)
                    error
                end
              error ->
                Logger.error("Failed to auto-register user '#{sender.handle}': #{inspect error}")
                self_registration_failed(request, state)
                :error
            end
          _ ->
            Logger.error("Failed to auto-register user '#{sender.handle}'. No suitable username was found.")
            self_registration_failed(request, state)
            :error
        end
    end
  end
  defp self_register_user(_, _, _) do
    :ok
  end

  defp self_registration_success(user, request, state) do
    provider = request.adapter
    handle = request.sender.handle
    {:ok, mention_name} = Cog.Chat.Adapter.mention_name(provider, handle)

    context = %{"results" => [%{"first_name" => request.sender.first_name,
                                "username" => user.username,
                                "mention_name" => mention_name}]}
    ReplyHelper.send("self_registration-success",
                     context,
                     request.room,
                     request.adapter,
                     state.mq_conn)
  end

  defp self_registration_failed(request, state) do
    provider = request.adapter
    handle = request.sender.handle
    {:ok, mention_name} = Cog.Chat.Adapter.mention_name(provider, handle)
    {:ok, display_name} = Cog.Chat.Adapter.display_name(provider)

    context = %{"results" => [%{"mention_name" => mention_name,
                                "display_name" => display_name}]}
    ReplyHelper.send("self_registration-failed",
                     context,
                     request.room,
                     request.adapter,
                     state.mq_conn)
  end

  defp find_available_username(username) do
    case Users.is_username_available?(username) do
      true ->
        {:ok, username}
      false ->
        find_available_username(username, 1)
    end
  end
  defp find_available_username(_username, 21) do
    :error
  end
  defp find_available_username(username, tries) do
    full_username = "#{username}_#{tries}"
    case Users.is_username_available?(full_username) do
      true ->
        {:ok, full_username}
      false ->
        find_available_username(username, tries + 1)
    end
  end
end
