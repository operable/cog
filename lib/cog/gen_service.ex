defmodule Cog.GenService do
  @moduledoc """
  Defines a service to be used by a command.

  # Callbacks

  ## service_init/1

  This is the place to put any initialization. You can think of it working just
  liek the init/1 callback for a GenServer. The reason for the custom callback,
  is that we do some initial setup in the `init/1` callback already before
  calling into your custom initialization callback.

  ## handle_message/3

  Here is where you should put the interesting bits of the service. Typically
  you'll pattern match based on the name and use the payload from the decoded
  request to do some work before responding with one of the following:

      {:reply, response, req, state}

      {:noreply, state}

  # Service Name

  By default, the service name, the name used to call the service from a
  command, is the lower-cased terminal segment of the module name. That is, if
  you implement a service in the `MyCompany.My.Great.Services.Foo`, then the
  servicename will be `foo`.

  To override it, pass in a new name as an argument to using GenService:

      defmodule This.Is.My.SuperSnazzyService do
        use #{inspect __MODULE__}, name: "super-service"
        # ...
      end

  # Caching

  Each service includes caching functions `cache_insert/2` and
  `cache_lookup/1`. Also, a cache ttl config option, used to expired stale
  items, can be optionally set along with your service config as the service
  name with the suffix `_cache_ttl`.
  """

  import Cog.Helpers, only: [module_key: 1]

  @callback service_init([any()] | []) :: {:ok, any()} | {:error, atom()}
  @callback handle_message(String.t, Spanner.Service.Request.t, any()) :: {:reply, String.t, String.t, any()} | {:noreply, any()}

  defmacro __using__(opts) do
    service_name = case opts do
      [name: name] ->
        name
      _ ->
        module_key(__CALLER__.module)
    end

    quote location: :keep do
      @behaviour Cog.GenService

      use GenServer
      import Cog.Helpers, only: [ensure_integer: 1]
      alias Carrier.Messaging.Connection
      alias Cog.Time
      require Logger


      @name unquote(service_name)
      @topic "/bot/services/#{@name}/+"
      @reap_interval 1800 # milliseconds
      @cache_ttl_key :"#{@name}_cache_ttl"

      defstruct mq_conn: nil, cb_state: nil

      def start_link do
        GenServer.start_link(__MODULE__, [])
      end

      def init(args) do
        {:ok, conn} = Connection.connect
        Logger.debug("Service subscribing to #{@topic}")
        Connection.subscribe(conn, @topic)

        cache_create

        case service_init(args) do
          {:ok, cb_state} ->
            {:ok, %__MODULE__{mq_conn: conn, cb_state: cb_state}}
          error ->
            error
        end
      end

      def handle_info({:publish, "/bot/services/" <> _, message}, state) do
        case Carrier.CredentialManager.verify_signed_message(message) do
          {true, payload} ->
            req = Spanner.Service.Request.decode!(payload)
            @name <> "/" <> action = req.service

            case handle_message(action, req, state.cb_state) do
              {:reply, reply, req, cb_state} ->
                new_state = %{state | cb_state: cb_state}
                {:noreply, send_ok_reply(reply, req, new_state)}
              {:noreply, cb_state}
                new_state = %{state | cb_state: cb_state}
                {:noreply, new_state}
            end
          false ->
            Logger.error("Message signature not verified! #{inspect message}")
            {:noreply, state}
        end
      end
      def handle_info(:reap, state) do
        spawn_link(fn ->
          cache_reap
        end)

        {:noreply, state}
      end
      def handle_info(_, state) do
        {:noreply, state}
      end

      defp send_ok_reply(reply, req, state) do
        resp = %Spanner.Service.Response{service: req.service, req_id: req.req_id, response: reply}
        |> Spanner.Service.Response.encode!

        Connection.publish(state.mq_conn, resp, routed_by: req.reply_to)
      end

      defp cache_create do
        :ets.new(__MODULE__, [:public, :named_table])
        :timer.send_interval(@reap_interval, :reap)
      end

      defp cache_insert(value, key) do
        expiry = Cog.Time.now + cache_ttl
        Logger.debug("Caching #{key} with expiry of #{expiry}")
        :ets.insert(__MODULE__, {key, {value, expiry}})
        value
      end

      def cache_lookup(key) do
        current_time = Time.now

        value = case :ets.lookup(__MODULE__, key) do
          [] ->
            Logger.debug("Couldn't find #{key} in the cache")
            nil
          [{_, {_, expiry}}] when expiry < current_time ->
            Logger.debug("Ignoring stale #{key} from cache")
            nil
          [{_, {entry, _}}] ->
            Logger.debug("Retrieving #{key} from cache")
            entry
        end
      end

      defp cache_reap do
        reap(__MODULE__)
      end

      defp reap(table) do
        :ets.safe_fixtable(table, true)
        reap(table, :ets.first(table))
      end

      defp reap(table, :"$end_of_table") do
        :ets.safe_fixtable(table, false)
      end
      defp reap(table, key) do
        maybe_delete_key(table, key)
        reap(table, :ets.next(table, key))
      end

      defp maybe_delete_key(table, key) do
        current_time = Time.now

        case :ets.lookup(table, key) do
          [{_, {_, expiry}}] when expiry < current_time ->
            Logger.debug("Reaping #{inspect key} from #{table}")
            :ets.delete(table, key)
          _ ->
            nil
        end
      end

      defp cache_ttl do
        Application.get_env(:cog, :services)
        |> Keyword.get(@cache_ttl_key, 300)
        |> ensure_integer
      end

      def service_init(_args) do
        {:ok, []}
      end

      def handle_message(_name, _req, state) do
        {:noreply, state}
      end

      def name(),
        do: unquote(service_name)

      defoverridable [service_init: 1, handle_message: 3]
    end
  end

  @doc """
  Returns `true` if `module` implements the
  `#{inspect __MODULE__}` behaviour.
  """
  def is_service?(module) do
    # Only Elixir modules have `__info__`
    attributes = try do
                   module.__info__(:attributes)
                 rescue
                   UndefinedFunctionError -> []
                 end
    behaviours = Keyword.get(attributes, :behaviour, [])
    __MODULE__ in behaviours
  end
end
