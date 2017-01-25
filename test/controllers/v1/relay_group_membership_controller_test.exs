defmodule Cog.V1.RelayGroupMembershipControllerTest do

  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.Bundle

  @relay_create_attrs %{name: "test-relay-1", token: "foo"}
  @relay_group_create_attrs %{name: "test-relay-group-1"}

  setup do
    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token

    # We add the user to a group and grant that group the appropriate permissions
    group = group("robots")
    role = role("monkey")
    Groupable.add_to(authed_user, group)
    Permittable.grant_to(group, role)
    Permittable.grant_to(role, permission("#{Cog.Util.Misc.embedded_bundle}:manage_relays"))
    Permittable.grant_to(role, permission("#{Cog.Util.Misc.embedded_bundle}:manage_commands"))

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    {:ok, [authed: authed_user,
           unauthed: unauthed_user,
           group: group]}
  end

  test "shows chosen resource", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_group = relay_group("test-relay-group-1")
    add_relay_to_group(relay_group.id, relay.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}/relays")
    relay_id = relay.id
    relay_name = relay.name

    assert [%{"id" => ^relay_id,
              "name" => ^relay_name}] = json_response(conn, 200)["relays"]
  end

  test "relay group includes member relays", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_group = relay_group("test-relay-group-1")
    add_relay_to_group(relay_group.id, relay.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}")
    fetched = json_response(conn, 200)

    # Assign variables to be used in matches below
    relay_group_id = relay_group.id
    relay_group_name = relay_group.name
    relay_id = relay.id
    relay_name = relay.name

    assert %{"relay_group" =>
              %{"id"     => ^relay_group_id,
                "name"   => ^relay_group_name,
                "relays" => [
                  %{"id"   => ^relay_id,
                    "name" => ^relay_name}
                ]
               }
            } = fetched
  end

  test "relay group, relays index includes member relays", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_group = relay_group("test-relay-group-1")
    add_relay_to_group(relay_group.id, relay.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}/relays")
    fetched = json_response(conn, 200)

    # Assign variables to be used in matches below
    relay_id = relay.id
    relay_name = relay.name

    assert %{"relays" => [
             %{"id"   => ^relay_id,
               "name" => ^relay_name}
           ]} = fetched
  end

  test "relay group includes assigned bundles", %{authed: requestor} do
    bundle = bundle_version("foo").bundle
    relay_group = relay_group("test-relay-group-1")
    assign_bundle_to_group(relay_group.id, bundle.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}")
    fetched = json_response(conn, 200)

    # Assign variables to be used in matches below
    relay_group_id = relay_group.id
    relay_group_name = relay_group.name
    bundle_id = bundle.id
    bundle_name = bundle.name

    assert %{"relay_group" =>
              %{"id"     => ^relay_group_id,
                "name"   => ^relay_group_name,
                "bundles" => [
                  %{"id"   => ^bundle_id,
                    "name" => ^bundle_name}
                ]
               }
            } = fetched
  end

  test "relay group, bundles index includes assigned bundles", %{authed: requestor} do
    bundle = bundle_version("foo").bundle
    relay_group = relay_group("test-relay-group-1")
    assign_bundle_to_group(relay_group.id, bundle.id)
    conn = api_request(requestor, :get, "/v1/relay_groups/#{relay_group.id}/bundles")
    fetched = json_response(conn, 200)

    # Assign variables to be used in matches below
    bundle_id = bundle.id
    bundle_name = bundle.name

    assert %{"bundles" => [
             %{"id"   => ^bundle_id,
               "name" => ^bundle_name}
           ]} = fetched
  end

  test "relay includes relay_group memberships", %{authed: requestor} do
    relay = relay("test-relay-1", "foo")
    relay_groups =
      for name <- ["test-relay-group-1", "test-relay-group-2"] do
        rg = relay_group(name)
        add_relay_to_group(rg.id, relay.id)
        rg.id
      end |> Enum.sort

    conn = api_request(requestor, :get, "/v1/relays/#{relay.id}")
    fetched = json_response(conn, 200)["relay"]

    # Assign variables to be used in matches below
    relay_id =  relay.id
    relay_name = relay.name

    assert %{"id"     => ^relay_id,
             "name"   => ^relay_name,
             "groups" => groups} = fetched

    fetched_groups =
      groups
      |> Enum.map(&(Map.get(&1, "id")))
      |> Enum.sort
    assert fetched_groups == relay_groups
  end

  @tag :skip # until the new bundle API settles down
  test "bundle includes relay_group assignments", %{authed: requestor} do
    bundle = bundle_version("foo").bundle
    relay_groups =
      for name <- ["test-relay-group-1", "test-relay-group-2"] do
        rg = relay_group(name)
        assign_bundle_to_group(rg.id, bundle.id)
        rg.id
      end |> Enum.sort

    conn = api_request(requestor, :get, "/v1/bundles/#{bundle.id}")
    fetched = json_response(conn, 200)["bundle"]

    # Assign variables to be used in matches below
    bundle_id =  bundle.id
    bundle_name = bundle.name

    assert %{"id"           => ^bundle_id,
             "name"         => ^bundle_name,
             "relay_groups" => groups} = fetched

    fetched_groups =
      groups
      |> Enum.map(&(Map.get(&1, "id")))
      |> Enum.sort
    assert fetched_groups == relay_groups
  end

  test "adding relays via REST endpoint", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    relays = for name <- ["test-relay-1", "test-relay-2", "test-relay-3"] do
      relay(name, "foo")
    end
    relay_ids = Enum.sort(Enum.map(relays, &(&1.id)))
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/relays",
                       body: %{"relays" => %{"add" => relay_ids}})
    updated = json_response(conn, 200)["relay_group"]
    updated_relays =
      updated["relays"]
      |> Enum.map(&(Map.get(&1, "id")))
      |> Enum.sort

    relay_group_id = relay_group.id
    relay_group_name = relay_group.name

    assert %{"id" => ^relay_group_id,
             "name" => ^relay_group_name} = updated
    assert relay_ids == updated_relays
  end

  test "adding relays fails if any relay does not exist", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    relays = for name <- ["test-relay-1", "test-relay-2", "test-relay-3"] do
      relay(name, "foo")
    end
    relay_ids = Enum.sort(Enum.map(relays, &(&1.id)))

    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/relays",
                       body: %{"relays" => %{"add" => ["bad_id" | relay_ids]}})

    response = json_response(conn, 422)["errors"]
    assert %{"bad_id" => %{"relays" => ["bad_id"]}} = response
  end

  test "removing relays via REST endpoint", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    relays = for name <- ["test-relay-1", "test-relay-2", "test-relay-3"] do
      relay(name, "foo")
    end
    for relay <- relays do
      add_relay_to_group(relay_group.id, relay.id)
    end
    [keep|to_remove] = Enum.sort(Enum.map(relays, &(&1.id)))
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/relays",
                       body: %{"relays" => %{"remove" => to_remove}})

    relay_group_id = relay_group.id
    relay_group_name = relay_group.name

    assert %{"relay_group" =>
              %{"id"     => ^relay_group_id,
                "name"   => ^relay_group_name,
                "relays" => [%{"id" => ^keep}]}} = json_response(conn, 200)
  end

  test "adding bundles via REST endpoint", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    bundles =
      for name <- ["test-bundle-1", "test-bundle-2", "test-bundle-3"] do
        bundle_version(name).bundle
      end
    bundle_ids = Enum.sort(Enum.map(bundles, &(&1.id)))
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/bundles",
                       body: %{"bundles" => %{"add" => bundle_ids}})

    relay_group_id = relay_group.id
    relay_group_name = relay_group.name

    assert %{"relay_group" =>
              %{"id"      => ^relay_group_id,
                "name"    => ^relay_group_name,
                "bundles" => group_bundles}} = json_response(conn, 200)

    sorted_response =
      group_bundles
      |> Enum.map(&(Map.get(&1, "id")))
      |> Enum.sort
    assert bundle_ids == sorted_response
  end

  Enum.each([Cog.Util.Misc.embedded_bundle, Cog.Util.Misc.site_namespace], fn(bundle_name)->
    test "cannot assign protected bundle #{bundle_name} to a relay", %{authed: requestor} do
      relay_group = relay_group("test-group")

      %Bundle{id: id} = Cog.Repo.get_by!(Bundle, name: unquote(bundle_name))
      conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/bundles",
                         body: %{"bundles" => %{"add" => [id]}})

      assert %{"protected_bundle" => unquote(bundle_name)} = json_response(conn, 422)["errors"]
    end
  end)

  test "adding bundles fails if a bundle does not exist", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    bundles =
      for name <- ["test-bundle-1", "test-bundle-2", "test-bundle-3"] do
        bundle_version(name).bundle
      end
    bundle_ids = Enum.sort(Enum.map(bundles, &(&1.id)))
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/bundles",
                       body: %{"bundles" => %{"add" => ["bad_id" | bundle_ids]}})

    response = json_response(conn, 422)["errors"]
    assert %{"bad_id" => %{"bundles" => ["bad_id"]}} = response
  end

  test "removing bundles via REST endpoint", %{authed: requestor} do
    relay_group = relay_group("test-relay-group-3")
    bundles = for name <- ["test-bundle-1", "test-bundle-2", "test-bundle-3"] do
      bundle_version(name).bundle
    end
    for bundle <- bundles do
      assign_bundle_to_group(relay_group.id, bundle.id)
    end

    [keep|to_remove] = Enum.sort(Enum.map(bundles, &(&1.id)))
    conn = api_request(requestor, :post, "/v1/relay_groups/#{relay_group.id}/bundles",
                       body: %{"bundles" => %{"remove" => to_remove}})

    relay_group_id = relay_group.id
    relay_group_name = relay_group.name

    assert %{"relay_group" =>
              %{"id"     => ^relay_group_id,
                "name"   => ^relay_group_name,
                "bundles" => [%{"id" => ^keep}]}} = json_response(conn, 200)
  end

end
