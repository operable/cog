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

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"add" => [user.username]}}})

    assert conn.halted
    assert conn.status == 403

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "fails if group doesn't exist", %{authed: requestor} do
    user = user("hal")

    error = catch_error(api_request(requestor, :post, "/v1/groups/#{@bad_uuid}/membership",
                                    body: %{"members" => %{"users" => %{"add" => [user.username]}}}))
    assert %Ecto.NoResultsError{} = error
  end

  # Add Users
  ########################################################################

  test "add a single user to a group", %{authed: requestor} do
    user = user("hal")
    group = group("robots")

    # user's got nothing yet!
    assert [] == Repo.preload(user, :direct_group_memberships).direct_group_memberships
    assert [] == Repo.preload(group, :direct_user_members).direct_user_members

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"add" => [user.username]}}})

    assert %{"members" => %{"users" => [%{"id" => user.id,
                                          "username" => user.username,
                                          "first_name" => user.first_name,
                                          "last_name" => user.last_name,
                                          "email_address" => user.email_address}],
                            "groups" => []}} == json_response(conn, 200)

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
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"add" => usernames}}})

    # # Verify the response body
    %{"members" => %{"users" => users_from_api,
                     "groups" => []}} = json_response(conn, 200)

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
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"add" => [new_user.username]}}})

    %{"members" => %{"users" => users_from_api,
                     "groups" => []}} = json_response(conn, 200)

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

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"add" => [existing_user.username,
                                                                     "i_dont_exist"]}}})
    assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"users" => ["i_dont_exist"]}}}

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "adding a user works even when the user is already a member", %{authed: requestor} do
    already_a_member = user("hal")
    group = group("robots")
    :ok = Groupable.add_to(already_a_member, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"add" => [already_a_member.username]}}})

    assert %{"members" => %{"users" => [%{"id" => already_a_member.id,
                                          "username" => already_a_member.username,
                                          "first_name" => already_a_member.first_name,
                                          "last_name" => already_a_member.last_name,
                                          "email_address" => already_a_member.email_address}],
                            "groups" => []}} == json_response(conn, 200)
  end

  # Add Groups
  ########################################################################

  test "add a single group to a group", %{authed: requestor} do
    group = group("robots")
    member = group("killer_robots")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"add" => [member.name]}}})

    assert %{"members" => %{"users" => [],
                            "groups" => [%{"id" => member.id,
                                           "name" => member.name}]}} == json_response(conn, 200)

    assert [member] == Repo.preload(group, :direct_group_members).direct_group_members
  end

  test "add multiple groups at once", %{authed: requestor} do
    group = group("robots")

    groupnames = ["killer_robots", "good_robots", "misunderstood_robots"]
    [killer, good, misunderstood] = Enum.map(groupnames, &group(&1))

    # Add groups as members
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"add" => groupnames}}})

    # # Verify the response body
    %{"members" => %{"users" => [],
                     "groups" => groups_from_api}} = json_response(conn, 200)

    # doing this indirect approach for now because Ecto doesn't like
    # to order `has_many through` preloads right now, apparently :(
    assert length(groups_from_api) == 3
    assert %{"id" => killer.id,
             "name" => killer.name} in groups_from_api
    assert %{"id" => good.id,
             "name" => good.name} in groups_from_api
    assert %{"id" => misunderstood.id,
             "name" => misunderstood.name} in groups_from_api
  end

  test "response from a membership grant includes all groups already in the group (i.e., not just the ones just added)", %{authed: requestor} do
    group = group("robots")
    original_member = group("killer_robots")
    Groupable.add_to(original_member, group)

    new_member = group("good_robots")
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"add" => [new_member.name]}}})

    %{"members" => %{"users" => [],
                     "groups" => groups_from_api}} = json_response(conn, 200)

    assert length(groups_from_api) == 2
    assert %{"id" => original_member.id,
             "name" => original_member.name} in groups_from_api
    assert %{"id" => new_member.id,
             "name" => new_member.name} in groups_from_api
  end

  test "fails all adds if any group does not exist", %{authed: requestor} do
    group = group("robots")
    existing_group = group("killer_robots")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"add" => [existing_group.name,
                                                                     "i_dont_exist"]}}})
    assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"groups" => ["i_dont_exist"]}}}

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  # Remove Users
  ########################################################################

  test "remove a single user from a group", %{authed: requestor} do
    user = user("hal")
    group = group("robots")
    Groupable.add_to(user, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"remove" => [user.username]}}})
    assert %{"members" => %{"users" => [],
                            "groups" => []}} == json_response(conn, 200)

    assert [] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "remove multiple users at once", %{authed: requestor} do
    group = group("robots")

    usernames = ["hal", "data", "robbie"]
    users = Enum.map(usernames, &user(&1))
    Enum.each(users, &Groupable.add_to(&1, group))

    # Remove
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"remove" => usernames}}})

    # # Verify the response body
    %{"members" => %{"users" => [],
                     "groups" => []}} = json_response(conn, 200)

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
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"remove" => [user_to_be_deleted.username]}}})

    # only the removed user is, um, removed
    assert %{"members" => %{"users" => [%{"id" => remaining_user.id,
                                          "username" => remaining_user.username,
                                          "first_name" => remaining_user.first_name,
                                          "last_name" => remaining_user.last_name,
                                          "email_address" => remaining_user.email_address}],
                            "groups" => []}} == json_response(conn, 200)
  end

  test "fails all removals if any user does not exist", %{authed: requestor} do
    group = group("robots")
    user = user("hal")
    Groupable.add_to(user, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"remove" => [user.username,
                                                                        "i_dont_exist"]}}})

    assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"users" => ["i_dont_exist"]}}}

    assert [user] == Repo.preload(group, :direct_user_members).direct_user_members
  end

  test "removing a user works even when the user wasn't a member in the first place", %{authed: requestor} do
    group = group("robots")
    not_a_member = user("hal")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"users" => %{"remove" => [not_a_member.username]}}})

    assert %{"members" => %{"users" => [],
                            "groups" => []}} == json_response(conn, 200)
  end

  # Remove groups
  ########################################################################

  test "remove a single group from a group", %{authed: requestor} do
    group = group("robots")
    member = group("killer_robots")
    Groupable.add_to(member, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"remove" => [member.name]}}})

    assert %{"members" => %{"users" => [],
                            "groups" => []}} == json_response(conn, 200)

    assert [] == Repo.preload(group, :direct_group_members).direct_group_members
  end

  test "remove multiple groups at once", %{authed: requestor} do
    group = group("robots")

    groupnames = ["hal", "data", "robbie"]
    groups = Enum.map(groupnames, &group(&1))
    Enum.each(groups, &Groupable.add_to(&1, group))

    # Remove
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"remove" => groupnames}}})

    # # Verify the response body
    %{"members" => %{"users" => [],
                     "groups" => []}} = json_response(conn, 200)

    assert [] == Repo.preload(group, :direct_group_members).direct_group_members
  end

  test "response from a remove includes all remaining group members of the group", %{authed: requestor} do
    # Give the group two members from the start
    group = group("robots")

    remaining_group = group("killer_robots")
    group_to_be_deleted = group("good_robots")
    Enum.each([remaining_group, group_to_be_deleted], &Groupable.add_to(&1, group))

    # Remove one of them
    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"remove" => [group_to_be_deleted.name]}}})

    # only the removed group is, um, removed
    assert %{"members" => %{"users" => [],
                            "groups" => [%{"id" => remaining_group.id,
                                           "name" => remaining_group.name}]}} == json_response(conn, 200)

    assert [remaining_group] == Repo.preload(group, :direct_group_members).direct_group_members
  end

  test "fails all removals if any group does not exist", %{authed: requestor} do
    group = group("robots")
    member = group("killer_robots")
    Groupable.add_to(member, group)

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"remove" => [group.name,
                                                                        "i_dont_exist"]}}})

    assert json_response(conn, 422) == %{"error" => %{"not_found" => %{"groups" => ["i_dont_exist"]}}}

    assert [member] == Repo.preload(group, :direct_group_members).direct_group_members
  end

  test "removing a group works even when the group wasn't a member in the first place", %{authed: requestor} do
    group = group("robots")
    not_a_member = group("killer_robots")

    conn = api_request(requestor, :post, "/v1/groups/#{group.id}/membership",
                       body: %{"members" => %{"groups" => %{"remove" => [not_a_member.name]}}})

    assert %{"members" => %{"users" => [],
                            "groups" => []}} == json_response(conn, 200)
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

    conn = api_request(requestor, :get, "/v1/groups/#{robots.id}/memberships")

    assert %{"members" => %{"users" => [user1, user2],
                            "groups" => [group]}} = json_response(conn, 200)

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
