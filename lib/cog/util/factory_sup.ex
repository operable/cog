defmodule Cog.Util.FactorySup do

  defmacro __using__(opts) do
    worker_mod = Keyword.fetch!(opts, :worker)
    worker_args = Keyword.get(opts, :args, [])

    quote do

      use Supervisor

      def start_link() do
        Supervisor.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init(_) do
        children = [worker(unquote(worker_mod), unquote(worker_args), restart: :temporary, shutdown: :brutal_kill)]
        supervise(children, strategy: :simple_one_for_one, max_restarts: 0, max_seconds: 1)
      end

    end

  end

end
