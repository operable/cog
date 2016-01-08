defmodule Cog.Service.ServiceSup do
  use Supervisor

  def start_link,
    do: Supervisor.start_link(__MODULE__, [])

  def init(_) do
    children = [worker(Cog.Services.Http, []),
                worker(Cog.Services.GitHub, []),
                worker(Cog.Services.EC2, []),
                worker(Cog.Services.S3, [])]
    supervise(children, strategy: :one_for_one)
  end

end
