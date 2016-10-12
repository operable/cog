defmodule Cog.Repo.Migrations.AddIrcChatProvider do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]
  alias Cog.Repo
  alias Cog.Models.ChatProvider

  def up do
    Repo.insert!(%ChatProvider{name: "irc"})
  end

  def down do
    Repo.delete_all(from p in ChatProvider, where: p.name == "irc")
  end
end
