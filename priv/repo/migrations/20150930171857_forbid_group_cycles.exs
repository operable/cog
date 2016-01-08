defmodule Cog.Repo.Migrations.ForbidGroupCycles do
  use Ecto.Migration

  def up do
    execute """
CREATE OR REPLACE FUNCTION forbid_group_cycles()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cycle_root BOOLEAN DEFAULT FALSE;
BEGIN
  SELECT INTO cycle_root (
      WITH RECURSIVE
          parents(id) AS (
              -- parent(s) of the current child group
              SELECT group_id
              FROM group_group_membership
              WHERE member_id = NEW.member_id

              UNION

              -- grandparents and other ancestors
              SELECT ggm.group_id
              FROM group_group_membership AS ggm
              JOIN parents AS p ON ggm.member_id = p.id
          )
      SELECT TRUE
      FROM parents
      WHERE id = NEW.member_id
  );

  IF cycle_root THEN
    RAISE EXCEPTION 'group cycles are forbidden';
  END IF;
  RETURN NULL;
END;
$$;
"""

    execute """
    CREATE CONSTRAINT TRIGGER no_long_range_cycles
    AFTER INSERT OR UPDATE
    ON group_group_membership
    FOR EACH ROW
    EXECUTE PROCEDURE forbid_group_cycles();
    """

  end

  def down do
    execute "DROP TRIGGER no_long_range_cycles ON group_group_membership;"
    execute "DROP FUNCTION forbid_group_cycles();"
  end
end
