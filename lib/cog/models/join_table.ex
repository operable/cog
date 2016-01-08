defmodule Cog.Models.JoinTable do
  alias Ecto.Adapters.SQL
  alias Cog.Repo

  @moduledoc """
  Many of our models have many-to-many associations amongst
  themselves. Examples include:

     User >--< Permission
     User >--< Roles
     Role >--< Permission
     Group >--< Permission
     User >--< Group

  and so on.

  In the database, these are modeled as simple "join tables" with two
  columns referring to the primary keys of the respective models being
  associated.

  The logic for inserting new rows into such tables is identical
  across all the legal pairings we have, and are also subject to a
  subtlety that is not currently handled well in native Ecto. Namely,
  we want inserts to be idempotent. That is, primary key violations in
  the join tables should be ignored (the constraint is still
  maintained, however). A solution can be had by dropping back to raw
  SQL, which this module implements generically for all such join
  tables in the system.

  In general, client code shouldn't be calling these functions
  directly, instead favoring specific wrapping interfaces (e.g., the
  `Permittable` protocol.

  """
  use Cog.Models

  def associate(lhs, %{__struct__: type}=rhs) when type in [Role, Permission] do
    lhs_type = struct_name(lhs)
    rhs_type = struct_name(rhs)

    lhs_id = "#{lhs_type}_id"
    rhs_id = "#{rhs_type}_id"

    table_name = table_name(lhs, rhs)

    execute_associate_query(table_name, lhs_id, rhs_id, lhs, rhs)
    :ok
  end
  def associate(member, %Group{}=group) do
    table_name = table_name(member, group)
    lhs_id = "member_id"
    rhs_id = "group_id"

    execute_associate_query(table_name, lhs_id, rhs_id, member, group)
    :ok
  end

  def dissociate(lhs, %{__struct__: type}=rhs) when type in [Role, Permission] do
    lhs_type = struct_name(lhs)
    rhs_type = struct_name(rhs)

    lhs_id = "#{lhs_type}_id"
    rhs_id = "#{rhs_type}_id"

    table_name = table_name(lhs, rhs)

    execute_dissociate_query(table_name, lhs_id, rhs_id, lhs, rhs)
    :ok
  end
  def dissociate(member, %Group{}=group) do
    table_name = table_name(member, group)
    lhs_id = "member_id"
    rhs_id = "group_id"

    execute_dissociate_query(table_name, lhs_id, rhs_id, member, group)
    :ok
  end

  defp execute_associate_query(table_name, lhs_id, rhs_id, lhs, rhs) do
    SQL.query!(Repo,
      """
      INSERT INTO #{table_name}(#{lhs_id}, #{rhs_id})
      SELECT $1, $2
      WHERE (NOT
              (EXISTS (
                SELECT * FROM #{table_name}
                WHERE #{lhs_id} = $1
                  AND #{rhs_id} = $2
              )))
           """,
      [Cog.UUID.uuid_to_bin(lhs.id),
       Cog.UUID.uuid_to_bin(rhs.id)])
  end

  defp execute_dissociate_query(table_name, lhs_id, rhs_id, lhs, rhs) do
    SQL.query!(Repo,
      """
      DELETE FROM #{table_name}
      WHERE #{lhs_id} = $1
        AND #{rhs_id} = $2
      """,
      [Cog.UUID.uuid_to_bin(lhs.id),
       Cog.UUID.uuid_to_bin(rhs.id)])
  end

  defp table_name(%User{}, %Permission{}),  do: "user_permissions"
  defp table_name(%User{}, %Role{}),        do: "user_roles"
  defp table_name(%Role{}, %Permission{}),  do: "role_permissions"
  defp table_name(%Group{}, %Permission{}), do: "group_permissions"
  defp table_name(%Group{}, %Role{}),       do: "group_roles"
  defp table_name(%Rule{}, %Permission{}),  do: "rule_permissions"

  defp table_name(%User{}, %Group{}),       do: "user_group_membership"
  defp table_name(%Group{}, %Group{}),      do: "group_group_membership"

  # Example:
  #
  #     iex> struct_name(%Cog.Models.User{})
  #     "user"
  defp struct_name(%{__struct__: type}) do
    type |> Module.split |> :lists.reverse |> hd |> String.downcase
  end

end
