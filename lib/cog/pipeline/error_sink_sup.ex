defmodule Cog.Pipeline.ErrorSinkSup do

  alias Cog.Pipeline.ErrorSink
  alias Cog.Util.FactorySup

  use FactorySup, worker: ErrorSink

  def create(opts) do
    Supervisor.start_child(__MODULE__, [opts])
  end

end
