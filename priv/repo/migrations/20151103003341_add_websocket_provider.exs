defmodule Cog.Repo.Migrations.AddWebsocketProvider do
  use Ecto.Migration
  import Ecto.Query, only: [from: 2]
  alias Cog.Repo
  alias Cog.Models.ChatProvider

  def up do
    Repo.insert!(%ChatProvider{name: "websocket"})
  end

  def down do
    from(p in ChatProvider, where: p.name == "websocket")
    |> Repo.delete_all
  end
end
