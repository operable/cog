defmodule Cog.PipelineSup do

  alias Cog.Util.FactorySup
  alias Cog.Pipeline

  use FactorySup, worker: Pipeline

  @doc ~s"""
  Creates a new `Cog.Pipeline` process

  See `Cog.Pipeline.create/1` for valid options
  """
  @spec create(Keyword.t) :: {:ok, pid} | {:error, any}
  def create(opts) do
    Supervisor.start_child(__MODULE__, [opts])
  end

end
