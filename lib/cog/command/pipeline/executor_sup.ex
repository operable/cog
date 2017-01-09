defmodule Cog.Command.Pipeline.ExecutorSup do
  alias Cog.Util.FactorySup
  alias Cog.Command.Pipeline.Executor

  use FactorySup, worker: Executor

  def run(%Cog.Messages.ProviderRequest{}=payload),
    do: Supervisor.start_child(__MODULE__, [payload])

end
