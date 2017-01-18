defmodule Cog.Pipeline.ExecutionStageSup do

  alias Cog.Util.FactorySup
  alias Cog.Pipeline.ExecutionStage

  use FactorySup, worker: ExecutionStage

  def create(opts) do
    Supervisor.start_child(__MODULE__, [opts])
  end

end
