defmodule Cog.Repo.Migrations.InsertFallbackTemplates do
  use Ecto.Migration
  alias Cog.Models.Template
  alias Cog.Repo

  def change do
    # That extra newline is there for a reason. Mustache spec strips newlines
    # following a standalone partial. No idea why.

    execute """
    INSERT INTO templates(id, name, adapter, source, inserted_at, updated_at)
    VALUES
    ('#{new_uuid}', 'json', 'slack',   '```\n{{> json}}\n\n```\n', now(), now()),
    ('#{new_uuid}', 'json', 'hipchat', '/code\n{{> json}}\n\n',    now(), now()),
    ('#{new_uuid}', 'raw',  'any',     '{{> json}}\n',           now(), now()),
    ('#{new_uuid}', 'json', 'any',     '{{> json}}\n',           now(), now()),
    ('#{new_uuid}', 'text', 'any',     '{{> text}}\n',           now(), now())
    """
  end

  defp new_uuid,
    do: UUID.uuid4(:hex)
end
