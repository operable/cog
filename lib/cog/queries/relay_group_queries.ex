defmodule Cog.Queries.RelayGroup do
  use Cog.Queries

  alias Cog.Models.RelayGroupMembership
  alias Cog.Repo

  def all() do
    from rg in RelayGroup,
    preload: [:relays]
  end

  def for_id(id) do
    all
    |> where([rg], rg.id == ^id)
  end

  def add_relays!(group_id, relay_ids) when is_list(relay_ids) do
    Enum.reduce(relay_ids, [], fn(id, acc) ->
      rgm = Repo.insert!(%RelayGroupMembership{relay_id: id,
                                               group_id: group_id})
      [rgm|acc]
    end)
  end

  def remove_relays(group_id, relay_ids) when is_list(relay_ids) do
    {count, _} = Repo.delete_all(from rgm in RelayGroupMembership,
                                 where: rgm.group_id == ^group_id and rgm.relay_id in ^relay_ids)
    count
  end

end
