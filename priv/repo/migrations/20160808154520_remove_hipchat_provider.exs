defmodule Cog.Repo.Migrations.RemoveHipchatProvider do
  use Ecto.Migration

  def up do
    execute """
    DELETE FROM templates WHERE adapter = 'hipchat'
    """
  end

  def down do
    execute """
    INSERT INTO templates(id, name, adapter, source, inserted_at, updated_at)
    VALUES ('#{new_uuid}', 'json', 'hipchat', '/code\n{{> json}}\n\n', now(), now())
    """
  end

  defp new_uuid,
    do: UUID.uuid4(:hex)

end
