defmodule Cog.Commands.Pipeline.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-list"

  alias Cog.Commands.Pipeline.Util
  alias Cog.Models.PipelineHistory
  alias Cog.Repository.PipelineHistory, as: HistoryRepo
  alias Cog.Repository.Users, as: UserRepo

  @description "Display command pipeline statistics"

  # Allow any user to run ps
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:pipeline-list allow"

  option "user", short: "u", type: "string", required: false,
    description: "View pipelines for specified user"

  option "last", short: "l", type: "int", required: false,
    description: "View <last> pipelines"

  option "expr", short: "e", type: "string", required: false,
    description: "Display only pipelines with command text matching regular expression <expr>"

  option "invert", short: "v", type: "bool", required: false,
    description: "Invert regular expression matching"

  option "runtime", short: "r", type: "int", required: false,
    description: "Display pipelines with a run time of at least <runtime> milliseconds"

  def handle_message(%{options: opts, pipeline_id: pipeline_id} = req, state) do
    case fetch_history(req, opts) do
      {:error, reason} ->
        {:error, req.reply_to, reason, state}
      {:ok, results} ->
        {regex_error, text_regex} = parse_regex(opts)
        if regex_error do
          {:error, req.reply_to, "Bad regular expression", state}
        else
          updated = results
              |> Enum.filter(&(&1.id != pipeline_id))
              |> Enum.filter(&text_matches?(&1, text_regex, Map.get(opts, "invert")))
              |> Enum.filter(&runtime_in_bounds?(&1, Map.get(opts, "runtime")))
              |> Enum.map(&Util.entry_to_map/1)
              |> Enum.map(&format_text/1)
          {:reply, req.reply_to, "pipeline-list", updated, state}
        end
    end
  end

  defp fetch_history(req, opts) do
    case Map.get(opts, "user") do
      nil ->
        {:ok, app_user} = UserRepo.by_username(req.requestor.handle)
        {:ok, HistoryRepo.history_for_user(app_user.id, Map.get(opts, "last", 20))}
      "all" ->
        {:ok, HistoryRepo.all_history(Map.get(opts, "last", 20))}
      user ->
        case UserRepo.by_username(user) do
          {:ok, app_user} ->
            {:ok, HistoryRepo.history_for_user(app_user.id, Map.get(opts, "last", 20))}
          {:error, :not_found} ->
            {:error, "User '#{user}' not found"}
        end
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

  defp format_text(entry) do
    if String.length(entry.text) > 15 do
      %{entry | text: String.slice(entry.text, 0, 12) <>  "..."}
    else
      entry
    end
  end

end
