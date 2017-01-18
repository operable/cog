defmodule Cog.Pipeline.ErrorSink do

  alias Experimental.GenStage
  alias Cog.Chat.Adapter, as: ChatAdapter
  alias Cog.Events.PipelineEvent
  alias Cog.Pipeline
  alias Cog.Pipeline.{Destination, DoneSignal, Errors}
  alias Cog.Template.Evaluator

  @moduledoc ~s"""
  Specialized `GenStage` consumer to handle pipeline processing errors. When the
  module encounters an error wrapped in a `Cog.Pipeline.DoneSignal` it will produce output
  appropriate for the pipeline type (trigger or interactive) and route it
  to the proper destination.
  """

  use GenStage

  require Logger

  @type t :: %__MODULE__{
    all_events: [] | [DoneSignal.t],
    conn: Carrier.Messaging.Connection.t,
    owner: pid,
    policy: Cog.Pipeline.output_policy,
    request: Cog.Messages.ProviderRequest.t,
    pipeline: pid,
    started: DateTime.t
  }

  defstruct [:pipeline, :policy, :owner, :request, :started, :all_events, :conn]

  @doc ~s"""
  Starts a new `ErrorSink` process and connects it to the parent pipeline.

  ## Options
  * `:conn` - Pipeline's shared MQTT connection. Required.
  * `:owner` - Pid of the pipeline's owner process. Required.
  * `:policy` - Pipeline output policy. Required.
  * `:pipeline` - Pid of the parent pipeline. Required.
  * `:started` - Pipeline start timestamp. Required.
  * `:upstream` - Pid of the preceding pipeline stage. Required.
  """
  @spec start_link(opts :: Keyword.t) :: {:ok, pid} | {:error, any}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(opts) do
    try do
      pipeline = Keyword.fetch!(opts, :pipeline)
      Process.monitor(pipeline)
      upstream = Keyword.fetch!(opts, :upstream)
      {:consumer, %__MODULE__{pipeline: pipeline,
                              owner: Keyword.fetch!(opts, :owner),
                              policy: Keyword.fetch!(opts, :policy),
                              request: Keyword.fetch!(opts, :request),
                              started: Keyword.fetch!(opts, :started),
                              conn: Keyword.fetch!(opts, :conn),
                              all_events: []},
       [subscribe_to: [upstream]]}
    rescue
      e in KeyError ->
        {:stop, {:error, Exception.message(e)}}
    end
  end

  def handle_events(events, _from, state) do
    events = Enum.filter(events, &DoneSignal.error?/1)
    state = state
            |> Map.update(:all_events, events, &(&1 ++ events))
            |> process_errors
    {:noreply, [], state}
  end

  def handle_info({:DOWN, _mref, _, pipeline, _}, %__MODULE__{pipeline: pipeline}=state) do
    {:stop, :normal, state}
  end
  def handle_info({:pipeline_complete, pipeline}, %__MODULE__{pipeline: pipeline}=state) do
    {:stop, :normal, state}
  end
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    Logger.debug("Error sink for pipeline #{state.request.id} shutting down")
  end

  defp process_errors(%__MODULE__{all_events: []}=state), do: state
  defp process_errors(state) do
    send_to_owner(state)
    state = if state.policy in [:adapter, :adapter_owner] do
      dests = Destination.here(state.request)
      Enum.each(state.all_events, &(send_to_adapter(&1, dests, state)))
      %{state | all_events: []}
    else
      state
    end
    Pipeline.teardown(state.pipeline)
    state
  end

  defp send_to_adapter(%DoneSignal{}=signal, dests, state) do
    Enum.each(dests, &(send_to_adapter(&1, signal, state)))
  end
  defp send_to_adapter({type, targets}, signal, state) do
    context = prepare_error_context(signal, state)
    failure_event(signal.error, context["error_message"], state)
    output = output_for(type, signal, context)
    Enum.each(targets, &ChatAdapter.send(state.conn, &1.provider, &1.room, output))
  end

  defp send_to_owner(%__MODULE__{all_events: events, policy: policy, owner: owner}=state) when policy in [:owner, :adapter_owner] do
    Process.send(owner, {:pipeline, state.request.id, {:error, events}}, [])
  end
  defp send_to_owner(_), do: :ok

  defp prepare_error_context(signal, state) do
    case signal.error do
      {:error, :user_not_found} ->
        handle   = state.request.sender.handle
        creators = user_creator_handles(state)
        {:ok, mention_name} = ChatAdapter.mention_name(state.conn, state.request.provider, handle)
        {:ok, display_name} = ChatAdapter.display_name(state.conn, state.request.provider)
        %{"handle" => handle,
          "mention_name" => mention_name,
          "display_name" => display_name,
          "user_creators" => creators}
      _ ->
        error_message = Errors.lookup(signal)
        %{"id" => state.request.id,
          "initiator" => sender_name(state.request),
          "started" => state.started,
          "pipeline_text" => state.request.text,
          "error_message" => error_message,
          "planning_failure" => "",
          "execution_failure" => error_message}
    end
  end

  defp output_for(:chat, %DoneSignal{template: nil}, context),
    do: Evaluator.evaluate("error-raw", context)
  defp output_for(:chat, signal, context),
    do: Evaluator.evaluate(signal.template, context)
  defp output_for(:trigger, _signal, context) do
    %{status: "error", pipeline_output: %{error_message: context["error_message"]}}
  end
  defp output_for(:status_only, _signal, context) do
    %{status: "error", pipeline_output: %{error_message: context["error_message"]}}
  end

  defp sender_name(request) do
    if ChatAdapter.is_chat_provider?(request.provider) do
      "@#{request.sender.handle}"
    else
      request.sender.id
    end
  end

  defp failure_event(error, error_message, state) do
    error_type = get_error_type(error)
    PipelineEvent.failed(state.request.id, state.started, error_type, error_message)
    |> Probe.notify
  end

  defp get_error_type({:error, type}), do: type
  defp get_error_type({:error, type, _}), do: type

  # Returns a list of provider-appropriate "mention names" of all Cog
  # users with registered handles for the provider that currently have
  # the permissions required to create and manipulate new Cog user
  # accounts.
  #
  # The intention is to create a list of people that can assist
  # immediately in-chat when unregistered users attempt to interact
  # with Cog. Not every Cog user with these permissions will
  # necessarily have a chat handle registered for the chat provider
  # being used (most notably, the bootstrap admin user).
  defp user_creator_handles(state) do
    provider = state.request.provider
    "operable:manage_users"
    |> Cog.Queries.Permission.from_full_name
    |> Cog.Repo.one!
    |> Cog.Queries.User.with_permission
    |> Cog.Queries.User.for_chat_provider(provider)
    |> Cog.Repo.all
    |> Enum.flat_map(&(&1.chat_handles))
    |> Enum.map(fn(h) ->
      {:ok, mention} = ChatAdapter.mention_name(state.conn, provider, h.handle)
      mention
    end)
    |> Enum.sort
  end

end
