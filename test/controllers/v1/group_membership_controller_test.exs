defmodule Cog.V1.GroupMembershipController.Test do
  use Cog.ModelCase
  use Cog.ConnCase

  @bad_uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    # Requests handled by the group membership controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_groups")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    {:ok, [authed: authed_user,
           unauthed: unauthed_user]}
  end

  # General
  ########################################################################

  test "unauthed users cannot add group members", %{unauthed: requestor} do
    user = user("hal")
    group = group("robots")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"add" => [user.username]}})

    assert conn.halted
    assert conn.status == 403

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "fails if group doesn't exist", %{authed: requestor} do
    user = user("hal")

    conn = api_request(requestor, :post, "/v1/groups/#{@bad_uuid}/users",
                                    body: %{"users" => %{"add" => [user.username]}})
    assert "Group not found" == json_response(conn, 404)["errors"]
  end

  # Add Users
  ########################################################################

  test "add a single user to a group", %{authed: requestor} do
    user = user("hal")
    group = group("robots")

    # user's got nothing yet!
    assert [] == Repo.preload(user, :direct_group_memberships).direct_group_memberships
    assert [] == Repo.preload(group, :direct_user_members).direct_user_members

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"add" => [user.username]}})

    assert %{"group" => %{"id" => group.id,
                          "name" => group.name,
                          "members" => %{"users" => [%{"id" => user.id,
                                                       "username" => user.username,
                                                       "first_name" => user.first_name,
                                                       "last_name" => user.last_name,
                                                       "email_address" => user.email_address}],
                                         "roles" => [],
                                         "groups" => []}}} == json_response(conn, 200)

    assert [user] == Repo.preload(group, :direct_user_members).direct_user_members
    assert [group] == Repo.preload(user, :direct_group_memberships).direct_group_memberships
  end

  test "add multiple users at once", %{authed: requestor} do
    group = group("robots")

    usernames = ["hal", "data", "robbie"]
    [hal, data, robbie] = users = Enum.map(usernames, &user(&1))

    # group's got nothing yet!
    assert [] == Repo.preload(group, :direct_user_members).direct_user_members

    # Grant the permissions
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"add" => usernames}})

    # # Verify the response body
    response = json_response(conn, 200)
    %{"users" => users_from_api,
      "roles" => [],
      "groups" => []} = response["group"]["members"]

    # doing this indirect approach for now because Ecto doesn't like
    # to order `has_many through` preloads right now, apparently :(
    assert length(users_from_api) == 3
    assert %{"id" => data.id,
             "username" => data.username,
             "first_name" => data.first_name,
             "last_name" => data.last_name,
             "email_address" => data.email_address} in users_from_api
    assert %{"id" => hal.id,
             "username" => hal.username,
             "first_name" => hal.first_name,
             "last_name" => hal.last_name,
             "email_address" => hal.email_address} in users_from_api
    assert %{"id" => robbie.id,
             "username" => robbie.username,
             "first_name" => robbie.first_name,
             "last_name" => robbie.last_name,
             "email_address" => robbie.email_address} in users_from_api

    # Each user should also have this group membership reflected
    Enum.each(users, fn(u) ->
      assert [group] == Repo.preload(u, :direct_group_memberships).direct_group_memberships
    end)
  end

  test "response from a membership grant includes all users already in the group (i.e., not just the ones just added)", %{authed: requestor} do
    original_user = user("hal")
    group = group("robots")
    Groupable.add_to(original_user, group)

    new_user = user("data")
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"add" => [new_user.username]}})

    response = json_response(conn, 200)
    %{"users" => users_from_api,
      "roles" => [],
      "groups" => []} = response["group"]["members"]

    assert length(users_from_api) == 2
    assert %{"id" => original_user.id,
             "username" => original_user.username,
             "first_name" => original_user.first_name,
             "last_name" => original_user.last_name,
             "email_address" => original_user.email_address} in users_from_api
    assert %{"id" => new_user.id,
             "username" => new_user.username,
             "first_name" => new_user.first_name,
             "last_name" => new_user.last_name,
             "email_address" => new_user.email_address} in users_from_api
  end

  test "fails all adds if any user does not exist", %{authed: requestor} do
    existing_user = user("hal")
    group = group("robots")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"add" => [existing_user.username,
                                                      "i_dont_exist"]}})
    assert json_response(conn, 422) == %{"errors" => %{"not_found" => %{"users" => ["i_dont_exist"]}}}

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "adding a user works even when the user is already a member", %{authed: requestor} do
    already_a_member = user("hal")
    group = group("robots")
    :ok = Groupable.add_to(already_a_member, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"add" => [already_a_member.username]}})

    assert %{"group" => %{"id" => group.id,
                          "name" => group.name,
                          "members" => %{"users" => [%{"id" => already_a_member.id,
                                                       "username" => already_a_member.username,
                                                       "first_name" => already_a_member.first_name,
                                                       "last_name" => already_a_member.last_name,
                                                       "email_address" => already_a_member.email_address}],
                                         "roles" => [],
                                         "groups" => []}}} == json_response(conn, 200)
  end

  # Remove Users
  ########################################################################

  test "remove a single user from a group", %{authed: requestor} do
    user = user("hal")
    group = group("robots")
    Groupable.add_to(user, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"remove" => [user.username]}})
    assert %{"group" => %{"id" => group.id,
                          "name" => group.name,
                          "members" => %{"users" => [],
                                         "roles" => [],
                                         "groups" => []}}} == json_response(conn, 200)

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "remove multiple users at once", %{authed: requestor} do
    group = group("robots")

    usernames = ["hal", "data", "robbie"]
    users = Enum.map(usernames, &user(&1))
    Enum.each(users, &Groupable.add_to(&1, group))

    # Remove
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"remove" => usernames}})

    # # Verify the response body
    response = json_response(conn, 200)
    %{"users" => [],
      "roles" => [],
      "groups" => []} = response["group"]["members"]

    # Each user should also have this group membership reflected
    Enum.each(users, fn(u) ->
      assert [] == Repo.preload(u, :direct_group_memberships).direct_group_memberships
    end)
  end

  test "response from a remove includes all remaining members of the group", %{authed: requestor} do
    # Give the group two members from the start
    group = group("robots")

    remaining_user = user("hal")
    user_to_be_deleted = user("data")
    Enum.each([remaining_user, user_to_be_deleted], &Groupable.add_to(&1, group))

    # Remove one of them
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"remove" => [user_to_be_deleted.username]}})

    # only the removed user is, um, removed
    assert %{"group" => %{"id" => group.id,
                          "name" => group.name,
                          "members" => %{"users" => [%{"id" => remaining_user.id,
                                                       "username" => remaining_user.username,
                                                       "first_name" => remaining_user.first_name,
                                                       "last_name" => remaining_user.last_name,
                                                       "email_address" => remaining_user.email_address}],
                                         "roles" => [],
                                         "groups" => []}}} == json_response(conn, 200)
  end

  test "fails all removals if any user does not exist", %{authed: requestor} do
    group = group("robots")
    user = user("hal")
    Groupable.add_to(user, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"remove" => [user.username,
                                                         "i_dont_exist"]}})

    assert json_response(conn, 422) == %{"errors" => %{"not_found" => %{"users" => ["i_dont_exist"]}}}

    assert [user] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "removing a user works even when the user wasn't a member in the first place", %{authed: requestor} do
    group = group("robots")
    not_a_member = user("hal")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/users",
                       body: %{"users" => %{"remove" => [not_a_member.username]}})

    assert %{"group" => %{"id" => group.id,
                          "name" => group.name,
                          "members" => %{"users" => [],
                                         "roles" => [],
                                         "groups" => []}}} == json_response(conn, 200)
  end

  test "retrieving user and group memberships for a group", %{authed: requestor} do
    robots = group("robots")
    hal = user("hal")
    bender = user("bender")
    Groupable.add_to(hal, robots)
    Groupable.add_to(bender, robots)

    user = user("deckard")
    androids = group("andriods")
    Groupable.add_to(user, androids)

    Groupable.add_to(androids, robots)

    conn = api_request(requestor, :get, "/v1/groups/#{robots.id}/users")

    assert %{"users" => [user1, user2],
             "roles" => [],
             "groups" => [group]} = json_response(conn, 200)["group"]["members"]

    [user1, user2] = Enum.sort([user1, user2], &(&1["username"] > &2["username"]))
    assert user1 == %{"id" => hal.id,
                      "username" => hal.username,
                      "first_name" => hal.first_name,
                      "last_name" => hal.last_name,
                      "email_address" => hal.email_address}

    assert user2 == %{"id" => bender.id,
                      "username" => bender.username,
                      "first_name" => bender.first_name,
                      "last_name" => bender.last_name,
                      "email_address" => bender.email_address}

    assert group == %{"id" => androids.id,
                      "name" => androids.name}
  end
end
