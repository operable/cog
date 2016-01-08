defmodule Cog.Repo.Migrations.AddCommandArgs do
  use Ecto.Migration

  def change do
    create table(:command_option_types, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
    end
    create unique_index(:command_option_types, [:name])
    execute """
create temp table option_type_names (
  name text not null
);
    """
    execute """
insert into option_type_names values ('int'), ('float'), ('bool'), ('string'), ('incr');
    """
    execute """
insert into command_option_types(id, name)
  select md5(random()::text || clock_timestamp()::text)::uuid, otn.name from option_type_names as otn;
    """
    execute """
drop table option_type_names;
    """
    create table(:command_options, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :command_id, references(:commands, type: :uuid, on_delete: :delete_all), null: false
      add :option_type_id, references(:command_option_types, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :desc, :text, null: true
      add :required, :boolean, null: false
      add :short_flag, :text, null: true
      add :long_flag, :text, null: true
    end
    create unique_index(:command_options, [:command_id, :name])
    execute """
ALTER TABLE command_options
  ADD CONSTRAINT flags_check CHECK(long_flag IS NOT NULL or short_flag IS NOT NULL);
    """
  end
end
