defmodule Cog.Repo.Migrations.AddPipelineHistory do
  use Ecto.Migration

  def up do
    create table(:user_history_counters, primary_key: false) do
      add :id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :value, :integer, null: false
    end
    create unique_index(:user_history_counters, [:id])

    # Populate user_history_counters from newly inserted user
    # table rows
    execute """
    create function create_user_history_counter() returns trigger as $proc$
    begin
      insert into user_history_counters values (new.id, 0);
      return new;
    end;
    $proc$ language plpgsql;
    """

    # Connect create_user_history_counter to users table
    execute """
    create trigger user_history_counter after insert on users
    for each row
    execute procedure create_user_history_counter();
    """

    # Create user_history_counters records for existing users
    execute """
    insert into user_history_counters (select id, 0 from users);
    """

    create table(:pipeline_history, primary_key: false) do
      add :id, :text, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :idx, :integer, null: true
      add :pid, :text, null: true
      add :text, :text, null: false
      add :count, :integer, null: false
      add :state, :text, null: false
      add :room, :text, null: false
      add :started_at, :bigint, null: false
      add :finished_at, :bigint, null: true

      timestamps
    end
    create index(:pipeline_history, [:user_id])
    create index(:pipeline_history, [:user_id, :idx])

    # Add per-user history index to new pipeine history records
    execute """
    create function add_history_index() returns trigger as $proc$
    begin
      update user_history_counters
        set value = value + 1 where id = NEW.user_id
        returning value into NEW.idx;
      return NEW;
    end
    $proc$ language plpgsql;
    """

    # Connect add_history_index to pipeline_history table
    execute """
    create trigger history_index before insert on pipeline_history
    for each row
    execute procedure add_history_index();
    """
  end

  def down do
    execute """
    drop trigger user_history_counter on users;
    """
    execute """
    drop function create_user_history_counter();
    """

    execute """
    drop trigger history_index on pipeline_history;
    """

    execute """
    drop function add_history_index();
    """

    drop table :pipeline_history
    drop table :user_history_counters
  end

end
