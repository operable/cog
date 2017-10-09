defmodule Cog.Pipeline.Initializer do
  @moduledoc """
  Listens for pipeline requests, triggering the execution of those
  pipelines.

  Additionalaly, tracks the history of requests being made, thus
  providing a "history" function, whereby a user may re-run the last
  request they made.
  """

  require Logger

  alias Carrier.Messaging.ConnectionSup
  alias Carrier.Messaging.Connection
  alias Cog.Command.Output
  alias Cog.{PipelineSup, Pipeline}
  alias Cog.Repository.Users
  alias Cog.Repository.ChatHandles
  alias Cog.Passwords

  defstruct mq_conn: nil, history: %{}, previous_command_token: ""

  use GenServer

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    previous_command_token = Application.get_env(:cog, :previous_command_token)
    {:ok, conn} = ConnectionSup.connect()
    Connection.subscribe(conn, "/bot/commands")
    Logger.info("Ready.")
    {:ok, %__MODULE__{mq_conn: conn, previous_command_token: previous_command_token}}
  end

  def handle_info({:publish, "/bot/commands", message}, state) do
    payload = Cog.Messages.ProviderRequest.decode!(message)
    # Only self register when the feature is enabled via config
    # and the incoming request is from Slack.
    #
    # TODO: should only do this if the provider is a chat provider
    self_register_flag = Application.get_env(:cog, :self_registration, false) and payload.provider != "http"
    case self_register_user(payload, self_register_flag, state) do
      :ok ->
        # TODO: should only do history check if the provider is a chat
        # provider, too
        case check_history(payload, state) do
          {true, payload, state} ->
            {:ok, runner} = PipelineSup.create([request: payload, output_policy: :adapter])
            Pipeline.run(runner)
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
    text = String.trim(payload.text)
    if text == state.previous_command_token do
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
    case Users.by_chat_handle(sender.handle, request.provider) do
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
                case ChatHandles.set_handle(user, request.provider, sender.handle) do
                  {:ok, _} ->
                    self_registration_success(user, request, state)
                    :ok
                  error ->
                    Logger.error("Failed to auto-register user '#{sender.handle}': #{inspect error}")
                    self_registration_failed(request, state)
                    :error
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
    provider = request.provider
    handle = request.sender.handle
    {:ok, mention_name} = Cog.Chat.Adapter.mention_name(state.mq_conn, provider, handle)

    context = %{"first_name" => request.sender.first_name,
                "username" => user.username,
                "mention_name" => mention_name}
    Output.send("self-registration-success", context,
                request.room, request.provider, state.mq_conn)
  end

  defp self_registration_failed(request, state) do
    provider = request.provider
    handle = request.sender.handle
    {:ok, mention_name} = Cog.Chat.Adapter.mention_name(state.mq_conn, provider, handle)
    {:ok, display_name} = Cog.Chat.Adapter.display_name(state.mq_conn, provider)

    context = %{"mention_name" => mention_name,
                "display_name" => display_name}
    Output.send("self-registration-failed", context,
                request.room, request.provider, state.mq_conn)
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
