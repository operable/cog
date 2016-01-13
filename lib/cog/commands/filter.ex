defmodule Cog.Commands.Filter do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, primitive: true

  @moduledoc """
  Filters collections. Filter is JSON aware

  ## Example

      @bot #{Cog.embedded_bundle}:filter --matches="/^Kev/" "Kevin" "John" "Kevina"
      > Kevin
      > Kevina

      @bot #{Cog.embedded_bundle}:stackoverflow vim | #{Cog.embedded_bundle}:filter --field="title" --return="title,link" --matches="/^Vim/" $items
      > { "title": "Vim clear last search highlighting",
          "link": "http://stackoverflow.com/users/65503/solomongaby" }
      > { "title": "Vim is great",
          "link": "http://stackoverflow.com/users/65504/solomongaby" }

  """

  option "matches", type: "string", required: false
  option "field", type: "string", required: false
  option "return", type: "string", required: false

  def handle_message(req, state) do
    lines = List.flatten(req.args)
    filtered_lines = filter(req.options, lines)
    |> maybe_pluck(req.options["return"])
    {:reply, req.reply_to, filtered_lines, state}
  end

  defp filter(%{"matches" => matches, "field" => field}, lines) do
    regex = compile_regex(matches)
    Enum.filter(lines, &(matches?(&1, regex, field)))
  end
  defp filter(%{"matches" => matches}, lines) do
    regex = compile_regex(matches)
    Enum.filter(lines, &(matches?(&1, regex)))
  end
  defp filter(_, lines) do
    lines
  end

  defp maybe_pluck([], _) do
    "No Matches"
  end
  defp maybe_pluck(lines, nil) do
    lines
  end
  defp maybe_pluck(lines, field_string) do
    if Enum.all?(lines, &is_map/1) do
      return_fields = String.split(field_string, ",")
      Enum.map(lines, fn(line) ->
        {new_map, _} = Map.split(line, return_fields)
        new_map
      end)
    else
      lines
    end
  end

  defp compile_regex(string) do
    case Regex.run(~r/^\/(.*)\/(.*)$/, string) do
      nil ->
        Regex.compile!(string)
      [_, regex, opts] ->
        Regex.compile!(regex, opts)
    end
  end

  defp matches?(obj, regex, field) when is_map(obj) and field != nil do
    matches?(obj[field], regex)
  end
  defp matches?(obj, regex, _) do
    matches?(obj, regex)
  end

  defp matches?(obj, regex) when is_map(obj),
    do: matches?(Poison.encode!(obj), regex)
  defp matches?(int, regex) when is_integer(int),
    do: matches?(Integer.to_string(int), regex)
  defp matches?(float, regex) when is_float(float),
    do: matches?(Float.to_string(float), regex)
  defp matches?(text, regex) when is_binary(text) do
    case Regex.run(regex, text) do
      nil -> false
      _ -> true
    end
  end

end
