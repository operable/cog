defmodule Cog.PipelineCoreSup do

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [supervisor(Cog.Pipeline.InitialContextSup, []),
                supervisor(Cog.Pipeline.ExecutionStageSup, []),
                supervisor(Cog.Pipeline.ErrorSinkSup, []),
                supervisor(Cog.Pipeline.OutputSinkSup, []),
                supervisor(Cog.PipelineSup, []),
                worker(Cog.Pipeline.PermissionsCache, []),
                worker(Cog.Pipeline.Initializer, [])]
    {:ok, {%{strategy: :one_for_one, intensity: 10, period: 60}, children}}
  end

end
