defmodule Cog.Pipeline do

  @default_output_policy :adapter
  @default_command_timeout 60000

  alias Carrier.Messaging.{Connection, ConnectionSup}
  alias Cog.Events.PipelineEvent
  alias Cog.Chat.Adapter, as: ChatAdapter
  alias Cog.Command.{CommandResolver, PermissionsCache}
  alias Cog.Command.Pipeline.Destination
  alias Cog.Command.Service.Tokens
  alias Cog.Messages.ProviderRequest
  alias Cog.Models.EctoJson
  alias Cog.Pipeline.PrepareError
  alias Cog.Pipeline.{DataSignal, DoneSignal, ExecutionStageSup, ErrorSinkSup,
                      InitialContext, InitialContextSup, OutputSinkSup}
  alias Cog.Queries.User, as: UserQueries
  alias Cog.Repo
  alias Piper.Command.Ast
  alias Piper.Command.Parser
  alias Piper.Command.ParserOptions

  use GenServer

  require Logger

  @type output_policy :: :adapter | :owner | :adapter_owner

  defstruct [:policy, :owner, :request, :stages, :token, :conn, :started, :status]

  @doc """
  Starts a new pipeline and prepares it to begin
  processing

  ## Options
  * `:request` - Originating `Cog.Messages.ProviderRequest`. Required.
  * `:owner` - Pid of pipeline owner. Optional.
  * `:output_policy` - Controls where to send output. Valid values for this option are:
    * `:adapter` - Pipeline will send output via `Cog.Chat.Adapter` (default)
    * `:owner` - Pipeline will forward output to the owning process. Requires `:owner` option.
    * `:adapter_owner` - Pipeline sends output via `Cog.Chat.Adapter` _and_ forwards
       a copy to the owning process. Requires `:owner` option.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, [opts])
  end

  @doc """
  Tells a prepared pipeline to begin executing
  """
  def run(pipeline) do
    GenServer.call(pipeline, :run, :infinity)
  end

  @doc """
  Notifies pipeline when processing is finished
  """
  def notify(pipeline) do
    GenServer.cast(pipeline, :teardown)
  end

  def init([opts]) do
    try do
       policy = Keyword.get(opts, :output_policy, @default_output_policy)
       request = Keyword.fetch!(opts, :request) |> sanitize_request
       owner = if policy in [:owner, :adapter_owner] do
         Keyword.fetch!(opts, :owner)
       else
         nil
       end
       case ConnectionSup.connect() do
         {:ok, conn} ->
           {:ok, %__MODULE__{policy: policy, owner: owner,
                             request: request, conn: conn,
                             token: Tokens.new(), status: :running}}
         error ->
           Logger.error("Failed to connect pipeline #{request.id} to message bus: #{inspect error}")
           {:stop, error}
       end
     rescue
       e in KeyError ->
         {:stop, {:missing_option, e.key}}
    end
  end

  def handle_call(:run, _from, state) do
    state = %{state | started: DateTime.utc_now()}
    case fetch_user(state) do
      {:ok, user} ->
        with {:ok, parsed, destinations} <- parse(user, state),
             {:ok, perms} <- PermissionsCache.fetch(user),
               user_json <- EctoJson.render(user) do
          start_pipeline(parsed, destinations, user_json, perms, state)
        else
          {:error, {:parse_error, message}} -> start_error_pipeline({:error, :parse_error, message}, user, state)
          error -> start_error_pipeline(error, user, state)
        end
      error ->
        start_error_pipeline(error, nil, state)
    end
  end
  def handle_call(_msg, _from, state) do
    {:reply, :ignored, state}
  end

  def handle_cast(:teardown, state) do
    duration = DateTime.to_unix(DateTime.utc_now, :milliseconds) - DateTime.to_unix(state.started, :milliseconds)
    Logger.info("Pipeline #{state.request.id} ran for #{duration} ms")
    {:stop, :normal, %{state | status: :done}}
  end
  def handle_cast(_, state) do
    {:noreply, state}
  end

  # Ignore monitor messages if the pipeline is done
  def handle_info({:DOWN, _, _, _, _}, %__MODULE__{status: :done}=state) do
    {:noreply, state}
  end
  # TODO Generate an error when a stage crashes
  def handle_info({:DOWN, _, _, stage, reason}, %__MODULE__{status: :running}=state) do
    if stage in state.stages do
      message = case reason do
                  {_, stacktrace} ->
                    "Pipeline #{state.request.id} crashed: #{inspect stacktrace, pretty: true}"
                  _ ->
                    "Pipeline #{state.request.id} crashed"
                end
      Logger.error(message)
      notify(self())
      {:noreply, %{state | status: :done}}
    else
      {:noreply, state}
    end
  end

  def terminate(_reason, state) do
    Connection.disconnect(state.conn)
  end

  defp sanitize_request(%ProviderRequest{text: text}=request) do
    prefix = Application.get_env(:cog, :command_prefix, "!")

    text = text
    |> String.replace(~r/^#{Regex.escape(prefix)}/, "") # Remove command prefix
    |> String.replace(~r/“|”/, "\"")      # Replace OS X's smart quotes and dashes with ascii equivalent
    |> String.replace(~r/‘|’/, "'")
    |> String.replace(~r/—/, "--")
    |> HtmlEntities.decode                # Decode html entities

    # TODO: Fold this into decoding of the request initially?
    %{request | text: text}
  end

  defp fetch_user(state) do
    # TODO: This should happen when we validate the request
    sender = state.request.sender.id
    if ChatAdapter.is_chat_provider?(state.conn, state.request.provider) do
      provider   = state.request.provider

      user = UserQueries.for_chat_provider_user_id(sender, provider)
      |> Repo.one

      case user do
        nil ->
          {:error, :user_not_found}
        user ->
          {:ok, user}
      end
    else
      case Repo.get_by(Cog.Models.User, username: sender) do
        %Cog.Models.User{}=user ->
          {:ok, user}
        nil ->
          {:error, :user_not_found}
      end
    end
  end

  defp parse(user, state) do
    options = %ParserOptions{resolver: CommandResolver.command_resolver_fn(user)}
    case Parser.scan_and_parse(state.request.text, options) do
      {:ok, %Ast.Pipeline{}=pipeline} ->
        case Destination.process(Ast.Pipeline.redirect_targets(pipeline),
                                 state.request.sender,
                                 state.request.room,
                                 state.request.provider) do
          {:ok, destinations} ->
            {:ok, pipeline, destinations}
          {:error, invalid} ->
            {:error, {:redirect_error, invalid}}
        end
      {:error, msg} ->
        {:error, {:parse_error, msg}}
    end
  end

  defp start_pipeline(parsed, destinations, user, perms, state) do
    case prepare_initial_context(state) do
      {:ok, context} ->
        case InitialContextSup.create([context: context, pipeline: self(), request_id: state.request.id]) do
          {:ok, initial_context} ->
            try do
              stages = parsed
                       |> Enum.with_index
                       |> Enum.reduce([initial_context], &create_stage!(&1, &2, user, perms, state))
                       |> create_sinks!(parsed, destinations, user, state)
              initialization_event(user, state)
              InitialContext.unlock(initial_context)
              {:reply, :ok, %{state | stages: stages}}
            rescue
              e in PrepareError ->
                start_error_pipeline({:error, Exception.message(e)}, user, state)
            end
          error ->
            start_error_pipeline(error, user, state)
        end
      error ->
        start_error_pipeline(error, user, state)
    end
  end

  defp create_stage!(invocation, [upstream|_]=stages, user, perms, state) do
    opts = stage_opts(invocation, user, perms, state)
    opts = [{:upstream, upstream}|opts]
    case ExecutionStageSup.create(opts) do
      {:ok, stage} ->
        Process.monitor(stage)
        [stage|stages]
      error ->
        raise PrepareError, [id: state.request.id, error: error, action: :create_stage]
    end
  end

  defp stage_opts({invocation, index}, user, perms, state) do
    [pipeline: self(), request_id: state.request.id,
     index: index, invocation: invocation, user: user,
     sender: state.request.sender, room: state.request.room,
     timeout: get_command_timeout(),
     permissions: perms, service_token: state.token, conn: state.conn]
  end

  defp create_sinks!([last|_]=stages, parsed, destinations, user, state) do
    opts = [pipeline: self(), pipeline: parsed, request: state.request, started: state.started,
            destinations: destinations, user: user, upstream: last,
            policy: state.policy, owner: state.owner, conn: state.conn]
    case ErrorSinkSup.create(opts) do
      {:ok, error_sink} ->
        Process.monitor(error_sink)
        case OutputSinkSup.create(opts) do
          {:ok, output_sink} ->
            Process.monitor(output_sink)
            [output_sink, error_sink] ++ stages
          error ->
            raise PrepareError, [id: state.request.id, error: error, action: :create_output_sink]
        end
      error ->
        raise PrepareError, [id: state.request.id, error: error, action: :create_error_sink]
    end
  end

  defp start_error_pipeline(error, user, state) do
    {:ok, initial_context} = InitialContextSup.create([context: [%DoneSignal{error: error, template: "error"}], pipeline: self(),
                                                       request_id: state.request.id])
    Process.monitor(initial_context)
    sink_opts = [pipeline: self(), request: state.request, started: state.started,
                 user: user, upstream: initial_context, policy: state.policy, owner: state.owner,
                 conn: state.conn]
    case ErrorSinkSup.create(sink_opts) do
      {:ok, error_sink} ->
        Process.monitor(error_sink)
        initialization_event(user, state)
        InitialContext.unlock(initial_context)
        {:reply, :ok, %{state | stages: [initial_context, error_sink]}}
      error ->
        raise PrepareError, [id: state.request.id, error: error, action: :create_error_sink]
    end
  end

  ########################################################################
  # Context Manipulation Functions

  # Each command in a pipeline has access to a "Cog Env", which is the
  # accumulated output of the execution of the pipeline thus far. This
  # is used as a binding context, as well as an input source for the
  # commands.
  #
  # The first command in a pipeline is different, though, as there is
  # no previous input. However, pipelines triggered by external events
  # (e.g., webhooks) can set the initial context to be, e.g., the body
  # of the HTTP request that triggered the pipeline.
  #
  # In the absence of an explicit initial context, a single empty map
  # is used. This provides an empty binding context for the first
  # command, preventing the use of unbound variables in the first
  # invocation of a pipeline. (For external-event initiated pipelines
  # with initial contexts, there can be variables in the first
  # invocation).
  #
  # In general, chat-provider initiated pipelines will not be supplied
  # with an initial context.
  defp prepare_initial_context(%__MODULE__{request: request}) do
    if is_list(request.initial_context) do
      if Enum.all?(request.initial_context, &is_map/1) do
        {:ok, Enum.map(request.initial_context, &DataSignal.wrap/1)}
      else
        {:error, :bad_initial_context}
      end
    else
      if is_map(request.initial_context) do
        {:ok, [DataSignal.wrap(request.initial_context)]}
      else
        {:error, :bad_initial_context}
      end
    end
  end

  defp get_command_timeout() do
    config = Application.fetch_env!(:cog, Cog.Command.Pipeline)
    case Keyword.get(config, :command_timeout) do
      nil ->
        Keyword.get(config, :interactive_timeout, @default_command_timeout)
      value ->
        value
    end
  end

  defp initialization_event(user, state) do
    PipelineEvent.initialized(state.request.id, state.started, state.request.text,
      state.request.provider, user.username, state.request.sender.handle) |> Probe.notify
  end

end
