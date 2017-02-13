defmodule Cog.Repository.PipelineHistory do
  @moduledoc """
  Behavioral API for interacting with pipeline history
  records.
  """

  import Ecto.Query, only: [from: 2]

  alias Cog.Repo
  alias Cog.Models.PipelineHistory

  @allowed_states ["running", "waiting", "finished"]

  @doc """
  Updates any pipelines in "running" or "waiting" states to "finished". This is intended
  to handle cases where Cog crashes (or similarly shuts down quickly) and leaves pipeline
  history records in an inconsistent state. This function should only be called when Cog
  is starting up.
  """
  def update_orphans() do
    {count, _} = from(ph in PipelineHistory,
                      where: ph.state != "finished",
                      update: [set: [state: "finished"]]) |> Repo.update_all([])
    count
  end

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

  def all_pipelines(limit \\ 20) do
    query = from ph in PipelineHistory,
            where: ph.state != "finished",
            order_by: [desc: :started_at],
            limit: ^limit,
            preload: [:user]
    Repo.all(query)
  end

  def pipelines_for_user(user_id, limit \\ 20) do
    query = from ph in PipelineHistory,
            where: ph.user_id == ^user_id and ph.state != "finished",
            order_by: [desc: :started_at],
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

  def history_for_user(user_id, hist_start, hist_end, limit \\ 20) do
    query  = build_user_history_query(user_id, hist_start, hist_end, limit)
    query = from q in query,
            where: q.state == "finished"
    Repo.all(query)
  end

  def history_entry(user_id, index) do
    query = from ph in PipelineHistory,
            where: ph.user_id == ^user_id and ph.idx == ^index
    Repo.one(query)
  end

  defp now_timestamp_ms() do
    DateTime.to_unix(DateTime.utc_now(), :milliseconds)
  end

  defp build_user_history_query(user_id, hist_start, hist_end, _limit) when hist_start != nil and hist_end != nil do
    from ph in PipelineHistory,
      where: ph.user_id == ^user_id and ph.idx >= ^hist_start and ph.idx <= ^hist_end,
      order_by: [desc: :idx],
      select: [ph.idx, ph.text]
  end
  defp build_user_history_query(user_id, hist_start, nil, limit) when hist_start != nil do
    from ph in PipelineHistory,
      where: ph.user_id == ^user_id and ph.idx >= ^hist_start,
      order_by: [desc: :idx],
      limit: ^limit,
      select: [ph.idx, ph.text]
  end
  defp build_user_history_query(user_id, nil, hist_end, limit) when hist_end != nil do
    from ph in PipelineHistory,
      where: ph.user_id == ^user_id and ph.idx <= ^hist_end,
      order_by: [desc: :idx],
      limit: ^limit,
      select: [ph.idx, ph.text]
  end
  defp build_user_history_query(user_id, nil, nil, limit) do
    from ph in PipelineHistory,
      where: ph.user_id == ^user_id,
      order_by: [desc: :idx],
      limit: ^limit,
      select: [ph.idx, ph.text]
  end

end
