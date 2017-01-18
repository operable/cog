defmodule Cog.Command.CommandSup do
  use Supervisor

  def start_link,
    do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    children = [supervisor(Cog.Command.Service.Supervisor, [])]
    supervise(children, strategy: :rest_for_one)
  end

end
