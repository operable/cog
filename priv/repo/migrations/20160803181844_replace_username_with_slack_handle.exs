defmodule Cog.Repo.Migrations.ReplaceUsernameWithSlackHandle do
  use Ecto.Migration

  def change do
    execute """
    UPDATE users
    SET username = chat_handles.handle
    FROM chat_handles, chat_providers
    WHERE users.username = users.email_address
      AND users.id = chat_handles.user_id
      AND chat_handles.provider_id = chat_providers.id
      AND chat_providers.name = 'slack';
    """
  end
end
