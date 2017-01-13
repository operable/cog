defmodule Cog.Pipeline.InitialContextSup do

  alias Cog.Util.FactorySup
  alias Cog.Pipeline.InitialContext

  use FactorySup, worker: InitialContext

  def create(opts) do
    Supervisor.start_child(__MODULE__, [opts])
  end

end
