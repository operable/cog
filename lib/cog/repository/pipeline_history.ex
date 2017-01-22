defmodule Cog.Repository.PipelineHistory do
  @moduledoc """
  Behavioral API for interacting with pipeline history
  records.
  """

  import Ecto.Query, only: [from: 2]

  alias Cog.Repo
  alias Cog.Models.PipelineHistory

  @allowed_states ["running", "waiting", "finished"]

  def new(attr) do
    attr = Map.put(attr, :started_at, now_timestamp_ms())
    cs = PipelineHistory.changeset(%PipelineHistory{}, attr)
    Repo.insert!(cs)
  end

  def increment_count(id, incr) do
    case Repo.get_by(PipelineHistory, id: id) do
      nil ->
        :ok
      ph ->
        cs = PipelineHistory.changeset(ph, %{count: ph.count + incr})
        Repo.update!(cs)
    end
  end

  def update_state(id, state) when state in @allowed_states do
    case Repo.get_by(PipelineHistory, id: id) do
      nil ->
        :ok
      ph ->
        args = if state == "finished" do
            %{state: state, finished_at: now_timestamp_ms()}
          else
            %{state: state}
          end
        cs = PipelineHistory.changeset(ph, args)
        Repo.update!(cs)
    end
  end

  def all_history(limit \\20) do
    query = from ph in PipelineHistory,
            order_by: [desc: :started_at],
            limit: ^limit,
            preload: [:user]
    Repo.all(query)
  end

  def history_for_user(user_id, limit \\ 20) do
    query = from ph in PipelineHistory,
            where: ph.user_id == ^user_id,
            order_by: [desc: :idx],
            limit: ^limit,
            preload: [:user]
    Repo.all(query)
  end

  def by_short_id(short_id, except_state \\ nil) when is_binary(short_id) do
    query = if except_state != nil do
      from ph in PipelineHistory,
      where: ph.state != ^except_state and like(ph.id, ^"#{short_id}%"),
      preload: [:user]
    else
      from ph in PipelineHistory,
      where: like(ph.id, ^"#{short_id}%"),
      preload: [:user]
    end
    Repo.one(query)
  end

  defp now_timestamp_ms() do
    DateTime.to_unix(DateTime.utc_now(), :milliseconds)
  end

end
