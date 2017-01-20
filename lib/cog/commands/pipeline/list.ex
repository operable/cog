defmodule Cog.Commands.Pipeline.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "pipeline-list"

  alias Cog.Pipeline.Tracker

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
    results = case Map.get(opts, "user") do
                nil ->
                  Tracker.pipelines_by(user: req.requestor.handle)
                "all" ->
                  Tracker.all_pipelines()
                user ->
                  Tracker.pipelines_by(user: user)
              end
    {regex_error, text_regex} = parse_regex(opts)
    if regex_error do
      {:error, req.reply_to, {:error, "Bad regular expression"}, state}
    else
      updated = results
              |> Enum.filter(&(String.starts_with?(pipeline_id, &1.id) == false))
              |> Enum.filter(&text_matches?(&1, text_regex, Map.get(opts, "invert")))
              |> Enum.filter(&runtime_in_bounds?(&1, Map.get(opts, "runtime")))
              |> limit(Map.get(opts, "last"))
      {:reply, req.reply_to, "pipeline-list", updated, state}
    end
  end

  defp limit(results, nil), do: results
  defp limit(results, count) do
    Enum.slice(results, 0, count)
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
    entry.elapsed >= min_rt
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

end
