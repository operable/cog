defmodule Cog.Repo.Migrations.GroupsForUserWithoutGroupGroupMembership do
  use Ecto.Migration

  def up do
    execute """
CREATE OR REPLACE FUNCTION groups_for_user(users.id%TYPE)
RETURNS TABLE(group_id groups.id%TYPE)
LANGUAGE SQL STABLE STRICT
AS $$
WITH RECURSIVE
  in_groups(id) AS (
    -- direct group membership
    SELECT group_id
    FROM user_group_membership
    WHERE member_id = $1
)
SELECT id from in_groups;
$$;
  """
  end

  def down do
    Code.eval_file("20150929173757_groups_for_user.exs", __DIR__)
    Cog.Repo.Migrations.GroupsForUser.up()
  end
end
