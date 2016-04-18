defmodule Cog.V1.RelayGroupMembershipController do
  use Cog.Web, :controller

  alias Cog.Models.RelayGroup
  alias Cog.Models.Bundle
  alias Cog.Models.Relay

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_relays"

  def index(conn, %{"id" => id}) do
    relay_group = Repo.get!(RelayGroup, id)
    render(conn, Cog.V1.RelayGroupView, "members.json", relay_group: relay_group)
  end

  def manage_membership(conn, %{"id" => id, "relays" => member_spec}),
  do: manage_association(conn, %{"id" => id, "members" => %{"relays" => member_spec}})

  def manage_assignment(conn, %{"id" => id, "bundles" => member_spec}),
  do: manage_association(conn, %{"id" => id, "members" => %{"bundles" => member_spec}})

  # Manage membership of a relay group. Adds and deletes can be submitted and
  # processed in a single request.
  def manage_association(conn, %{"id" => id, "members" => member_spec}) do
    _result = Repo.transaction(fn() ->
      relay_group = Repo.get!(RelayGroup, id)
      |> Repo.preload([:bundles, :relays])

      bundles_to_add    = lookup_or_fail(member_spec, ["bundles", "add"])
      relays_to_add     = lookup_or_fail(member_spec, ["relays", "add"])
      bundles_to_remove = lookup_or_fail(member_spec, ["bundles", "remove"])
      relays_to_remove  = lookup_or_fail(member_spec, ["relays", "remove"])

      relay_group
      |> add(relay_group.bundles -- bundles_to_add)

      %{relay_group: relay_group,
        add_bundles: bundles_to_add,
        add_relays: relays_to_add,
        remove_bundles: bundles_to_remove,
        remove_relays: relays_to_remove}
    end)

    #IO.inspect {"RESULTS", result}

    json(conn, %{"FOO" => member_spec})
  end

  defp lookup_or_fail(member_spec, [kind, _operation]=path) do
    names = get_in(member_spec, path) || []
    case lookup_all(kind, names) do
      {:ok, structs} -> structs
      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp lookup_all(_, []), do: {:ok, []} # Don't bother with a DB lookup
  defp lookup_all(kind, names) when kind in ["relays", "bundles"] do

    type = kind_to_type(kind) # e.g. "relays" -> Relay
    unique_name_field = unique_name_field(type) # e.g. Relay -> :name

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

  defp add(relay_group, members) do
    Enum.each(members, &Groupable.add_to(&1, relay_group))
    relay_group
  end


  # Given a member_spec key, return the underlying type
  defp kind_to_type("relays"), do: Relay
  defp kind_to_type("bundles"), do: Bundle

  # Given a type, return the field for its unique name
  defp unique_name_field(Relay), do: :id
  defp unique_name_field(Bundle), do: :id

      #to_add = build_members("add", type, member_spec)
      #to_remove = build_members("remove", type, member_spec)

      #case to_add.not_found ++ to_remove.not_found do
        #[] ->
          #RelayGroup.add!(type, group.id, to_add.found)
          #removed = RelayGroup.remove(type, group.id, to_remove.found)
          #if removed != length(to_remove.found) do
            #Repo.rollback(:remove_failed)
          #else
            #group
          #end
        #ids ->
          #Repo.rollback({:unknown_association, ids})
      #end
    #end)

    #case result do
      #{:ok, relay_group} ->
        #relay_group = Repo.one!(Queries.RelayGroup.for_id(relay_group.id))
        #render(conn, Cog.V1.RelayGroupView, "show.json", relay_group: relay_group)
      #{:error, reason} ->
        #errors = case reason do
                   #:remove_failed ->
                     #"delete_failed"
                   #{:unknown_association, ids} ->
                     #name = case type do
                              #:relay -> :relays
                              #:bundle -> :bundles
                            #end
                     #%{"not_found" => %{name => ids}}
                 #end
        #conn
        #|> put_status(:unprocessable_entity)
        #|> json(%{"errors" => errors})
    #end
    #json(conn, %{"FOO" => member_spec})
  #end

  #"add", :relay, %{"add" => ["relay1", "relay2"],
                   #"remove" => ["relay3", "relay4"]}

  #def build_members(action, type, member_spec) do
    #case Map.get(member_spec, action) do
      #nil ->
        #%{found: [], not_found: []}
      #member_ids ->
        #found = Enum.filter(member_ids, fn(id) -> verify_member(type, id) end)
        #not_found = member_ids -- found
        #%{found: found, not_found: not_found}
    #end
  #end

  #defp verify_member(type, id) do
    #model = case type do
              #:relay  -> Cog.Models.Relay
              #:bundle -> Cog.Models.Bundle
            #end
    #Cog.Repo.exists?(model, id)
  #end

end
