defmodule Cog.Commands.Pipeline.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-list"

  alias Cog.Commands.Pipeline.Util
  alias Cog.Models.PipelineHistory
  alias Cog.Repository.PipelineHistory, as: HistoryRepo
  alias Cog.Repository.Users, as: UserRepo

  @description "Display command pipeline statistics"
  @valid_state_names ["R","W","F","running","waiting","finished"]

  # Allow any user to run ps
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:pipeline-list allow"

  option "user", short: "u", type: "string", required: false,
    description: "View pipelines for specified user. Use 'all' to view pipeline history for all users."

  option "last", short: "l", type: "int", required: false,
    description: "View <last> pipelines"

  option "expr", short: "e", type: "string", required: false,
    description: "Display only pipelines with command text matching regular expression <expr>"

  option "invert", short: "v", type: "bool", required: false,
    description: "Invert regular expression matching"

  option "elapsed-time", short: "t", type: "int", required: false,
    description: "Display pipelines with a run time of at least <elpased-time> milliseconds"

  option "room", short: "r", type: "string", required: false,
    description: "Display only pipelines executed in <room>"

  option "state", short: "s", type: "string", required: false

  def handle_message(%{options: opts, pipeline_id: pipeline_id} = req, state) do
    case fetch_history(req, opts) do
      {:error, reason} ->
        {:error, req.reply_to, reason, state}
      {:ok, results} ->
        {regex_error, text_regex} = parse_regex(opts)
        if regex_error do
          {:error, req.reply_to, "Bad regular expression", state}
        else
          if valid_state_option?(opts) do
            invert = Map.get(opts, "invert")
            min_rt = Map.get(opts, "elapsed-time")
            room = Map.get(opts, "room")
            state_name = Map.get(opts, "state")
            updated = results
                      |> Enum.filter(&(&1.id != pipeline_id) and text_matches?(&1, text_regex, invert) and
                                       runtime_in_bounds?(&1, min_rt) and
                                       room_matches?(&1, room) and
                                       state_matches?(&1, state_name))
                      |> Enum.map(&(format_entry(Util.entry_to_map(&1))))
           results = %{pipeline_count: length(updated), pipelines: updated}
           {:reply, req.reply_to, "pipeline-list", results, state}
          else
            {:error, req.reply_to, "Valid state names are: #{Enum.join(@valid_state_names, ", ")}", state}
          end
        end
    end
  end

  defp fetch_history(req, opts) do
    case Map.get(opts, "user") do
      nil ->
        {:ok, HistoryRepo.pipelines_for_user(req.user["id"], Map.get(opts, "last", 20))}
      "all" ->
        {:ok, HistoryRepo.all_pipelines(Map.get(opts, "last", 20))}
      user ->
        case UserRepo.by_username(user) do
          {:ok, app_user} ->
            {:ok, HistoryRepo.pipelines_for_user(app_user.id, Map.get(opts, "last", 20))}
          {:error, :not_found} ->
            {:error, "User '#{user}' not found"}
        end
    end
  end

  defp valid_state_option?(opts) do
    case Map.get(opts, "state") do
      nil ->
        true
      name ->
        name in @valid_state_names
    end
  end

  defp text_matches?(_, nil, _), do: true
  defp text_matches?(entry, regex, invert) do
    if invert do
      not(Regex.match?(regex, entry.text))
    else
      Regex.match?(regex, entry.text)
    end
  end

  defp runtime_in_bounds?(_, nil), do: true
  defp runtime_in_bounds?(entry, min_rt) do
    PipelineHistory.elapsed(entry) >= min_rt
  end

  defp room_matches?(_, nil), do: true
  defp room_matches?(entry, room), do: entry.room_name == room

  defp state_matches?(_, nil), do: true
  defp state_matches?(entry, "F"), do: state_matches?(entry, "finished")
  defp state_matches?(entry, "W"), do: state_matches?(entry, "waiting")
  defp state_matches?(entry, "R"), do: state_matches?(entry, "running")
  defp state_matches?(entry, state), do: entry.state == state

  defp parse_regex(opts) do
    case Map.get(opts, "expr") do
      nil ->
        {false, nil}
      expr ->
        case Regex.compile(expr) do
          {:ok, cexpr} ->
            {false, cexpr}
          {:error, _} ->
            {true, nil}
        end
    end
  end

  defp format_entry(entry) do
    entry
    |> format_text
    |> short_state
  end

  defp format_text(entry) do
    if String.length(entry.text) > 15 do
      %{entry | text: String.slice(entry.text, 0, 12) <>  " ..."}
    else
      entry
    end
  end

  defp short_state(entry) do
    case entry.state do
      "finished" ->
        Map.put(entry, :state, "F")
      "waiting" ->
        Map.put(entry, :state, "W")
      "running" ->
        Map.put(entry, :state, "R")
    end
  end

end
