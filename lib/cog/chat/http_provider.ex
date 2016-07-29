defmodule Cog.Chat.HttpProvider do

  require Logger

  use GenServer
  use Cog.Chat.Provider

  def start_link(_config), do: GenServer.start_link(__MODULE__, [])

end
