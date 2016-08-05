defmodule Cog.Chat.TestProvider do

  use GenServer
  use Cog.Chat.Provider

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    {:ok, []}
  end

  def list_joined_rooms() do
    {:ok, [%Room{id: "general",
                 name: "general",
                 provider: "test",
                 is_dm: false}]}
  end

end
