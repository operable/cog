defmodule Cog.ChatSup do

  require Logger
  use Supervisor

  def start_link(), do: Supervisor.start_link(__MODULE__, [])

  def init(_) do
    :ok = Application.start(:cog_chat)
    children = [supervisor(Cog.Chat.Http.Supervisor, [])]
    {:ok, {%{strategy: :one_for_one, intensity: 10, period: 60}, children}}
  end

end
