defmodule Cog.WebSocketController do
  use Cog.Web, :controller

  def index(conn, _) do
    render conn, "index.html"
  end
end
