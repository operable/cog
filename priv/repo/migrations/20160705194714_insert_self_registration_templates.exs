defmodule Cog.Repo.Migrations.InsertSelfRegistrationTemplates do
  use Ecto.Migration

  def change do

    execute """
    INSERT INTO templates(id, name, adapter, source, inserted_at, updated_at)
    VALUES
    ('#{new_uuid}', 'self_registration_failed', 'any', '#{self_registration_failed_source}', now(), now()),
    ('#{new_uuid}', 'self_registration_success', 'any', '#{self_registration_success_source}', now(), now())
    """
  end

  defp self_registration_failed_source do
  """
  {{mention_name}}: Unfortunately I was unable to automatically create a Cog account for your {{display_name}} chat handle. Only users with Cog accounts can interact with me.

  You'll need to ask a Cog administrator to investigate the situation and set up your account.
  """ |> String.replace("'", "''") # postgres escaping
  end

  defp self_registration_success_source do
    """
  {{mention_name}}: Hello {{first_name}}! It's great to meet you! You're the proud owner of a shiny new Cog account named '{{username}}'.
    """ |> String.replace("'", "''") # postgres escaping
  end

  defp new_uuid,
    do: UUID.uuid4(:hex)

end
