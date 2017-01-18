defmodule Cog.Pipeline.OutputSinkSup do

  alias Cog.Util.FactorySup
  alias Cog.Pipeline.OutputSink

  use FactorySup, worker: OutputSink

  def create(opts) do
    Supervisor.start_child(__MODULE__, [opts])
  end

end
