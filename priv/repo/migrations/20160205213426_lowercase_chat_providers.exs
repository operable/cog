defmodule Cog.Repo.Migrations.LowercaseChatProviders do
  use Ecto.Migration

  def up do
    execute """
    UPDATE chat_providers SET name = lower(name)
    """
  end
end
