defmodule :"Elixir.Cog.Repo.Migrations.Delete_ssh_irc_websocket" do
  use Ecto.Migration

  def change do
    execute "DELETE FROM chat_providers where name in ('ssh', 'irc', 'websocket')"
  end
end
