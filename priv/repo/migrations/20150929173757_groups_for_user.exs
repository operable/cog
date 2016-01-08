defmodule Cog.Repo.Migrations.GroupsForUser do
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

    UNION

    -- indirect group membership; find parent groups of all groups
    -- the user is a direct member of, recursively
    SELECT ggm.group_id
    FROM group_group_membership AS ggm
    JOIN in_groups ON in_groups.id = ggm.member_id
)
SELECT id from in_groups;
$$;
"""
  end

  def down do
    execute "DROP FUNCTION groups_for_user(uuid)"
  end
end
