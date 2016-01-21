defmodule Cog.V1.GroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.User
  alias Cog.Models.Group

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_groups"

  def index(conn, %{"id" => id}) do
    group = Group
    |> Repo.get!(id)
    |> Repo.preload([:direct_user_members, :direct_group_members])

    users  = EctoJson.render(group.direct_user_members, policy: :detail)
    groups = EctoJson.render(group.direct_group_members, policy: :detail)

    json(conn, %{members: %{users: users, groups: groups}})
  end

  # Manage the membership of a group. Users and groups can be added
  # and removed (multiples of each, all at the same time!) using this
  # function. Everything is governed by the request body, which we'll
  # call a "member spec".
  #
  # %{"members" => %{"users" => %{"add" => ["user_to_add_1", "user_to_add_2"],
  #                               "remove" => ["user_to_remove"]},
  #                  "groups" => %{"add" => ["group_to_add_1", "group_to_add_2"],
  #                                "remove" => ["group_to_remove"]}}}
  #
  # Provide the usernames of Users, and the names of Groups that you
  # want to be members (or not) of the target group (as specified by
  # `id`). All changes are made transactionally, so if any given names
  # don't refer to a database entity, no changes in membership are
  # made.
  #
  # NOTE: As currently coded, this API endpoint is a bit too "chatty"
  # from a database interaction perspective. The resolution of names to
  # entities is only batched by type and operation (e.g., all users to add
  # are looked up at once), all these entities are returned from the
  # database, and each subsequent addition and removal are performed
  # one-at-a-time, rather than in bulk. As you can see, a request that
  # manipulates many users and groups at once could end up making
  # quite a few database calls.
  #
  # For the time being, in these early days, this is OK, but a
  # second-pass should be made. We can create a stored procedure that
  # takes all the names and does the resolution and membership changes
  # much more efficiently in a single operation.
  def manage_membership(conn, %{"id" => id, "members" => member_spec}) do
    result = Repo.transaction(fn() ->
      group = Repo.get!(Group, id)

      users_to_add     = lookup_or_fail(member_spec, ["users", "add"])
      groups_to_add    = lookup_or_fail(member_spec, ["groups", "add"])
      users_to_remove  = lookup_or_fail(member_spec, ["users", "remove"])
      groups_to_remove = lookup_or_fail(member_spec, ["groups", "remove"])

      group
      |> add(users_to_add ++ groups_to_add)
      |> remove(users_to_remove ++ groups_to_remove)
      |> Repo.preload(:direct_user_members)
      |> Repo.preload(:direct_group_members)
    end)

    case result do
      {:ok, group} ->
        conn
        |> json(%{members: %{users: EctoJson.render(group.direct_user_members, policy: :detail),
                             groups: EctoJson.render(group.direct_group_members, policy: :detail)}})

      # TODO: Aargh, can't (yet!) use variables as map keys! Wait for Elixir 1.2
      {:error, {:not_found, {"users", names}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"error" => %{"not_found" => %{"users" => names}}})
      {:error, {:not_found, {"groups", names}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"error" => %{"not_found" => %{"groups" => names}}})
    end
  end

  # Resolves the names given in the `member_spec` portion of the
  # request body into database entities.
  #
  # Calls `Repo.rollback/1` if any of the given names don't exist, so
  # run this inside a transaction.
  #
  # Example:
  #
  #     > lookup_or_fail(%{"users" => %{"add" => ["cog"]}},
  #                         ["users", "add"],
  #                         User)
  #     [%User{username: "cog", ...}]
  #
  defp lookup_or_fail(member_spec, [kind, _operation]=path) do
    names = get_in(member_spec, path) || []
    case lookup_all(kind, names) do
      {:ok, structs} -> structs
      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  # Helper to retrieve mulitple Users or Groups, given names, in one
  # database call.
  #
  # If any of the given names does not refer to an existing database
  # entity, an error tuple is returned with a list of all "bad" names.
  #
  # Example:
  #
  #     > lookup_all("users", ["cog"])
  #     {:ok, [%User{username: "cog", ...}]}
  #
  #     > lookup_all("users", ["not_a_user", "cog", "badguy"])
  #     {:error, {:not_found, {"users", ["not_a_user", "badguy"]}}}
  #
  defp lookup_all(_, []), do: {:ok, []} # Don't bother with a DB lookup
  defp lookup_all(kind, names) when kind in ["users", "groups"] do

    type = kind_to_type(kind) # e.g. "users" -> User
    unique_name_field = unique_name_field(type) # e.g. User -> :username

    results = Repo.all(from t in type, where: field(t, ^unique_name_field) in ^names)

    # make sure we got a result for each name given
    case length(results) == length(names) do
      true ->
        # Each name corresponds to an entity in the database
        {:ok, results}
      false ->
        # We got at least one name that doesn't map to any existing
        # user or group. Find out what's missing and report back
        retrieved_names = Enum.map(results, &Map.get(&1, unique_name_field))
        bad_names = names -- retrieved_names
        {:error, {:not_found, {kind, bad_names}}}
    end
  end

  # Add multiple `%User{}` or `%Group{}` members to `group`, returning
  # `group`.
  #
  # Note that `members` can be a mix of types.
  defp add(group, members) do
    Enum.each(members, &Groupable.add_to(&1, group))
    group
  end

  # Remove multiple `%User{}` or `%Group{}` members from `group`, returning
  # `group`.
  #
  # Note that `members` can be a mix of types.
  defp remove(group, members) do
    Enum.each(members, &Groupable.remove_from(&1, group))
    group
  end

  # Given a member_spec key, return the underlying type
  defp kind_to_type("users"), do: User
  defp kind_to_type("groups"), do: Group

  # Given a type, return the field for its unique name
  defp unique_name_field(User), do: :username
  defp unique_name_field(Group), do: :name

end
