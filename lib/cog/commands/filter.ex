defmodule Cog.Commands.Filter do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, calling_convention: :all

  @moduledoc """
  Filters a collection.

  ## Example

      @bot #{Cog.embedded_bundle}:rules --list --for-command="#{Cog.embedded_bundle}:permissions" | #{Cog.embedded_bundle}:filter --field="rule" --return="id, command" --matches="/manage_users/"
      > { "id": "91edb472-04cf-4bca-ba05-e51b63f26758",
          "command": "operable:permissions" }

  """

  option "matches", type: "string", required: false
  option "field", type: "string", required: false
  option "return", type: "string", required: false

  def handle_message(req, state) do
    item = maybe_match(req.options, req.cog_env)
    |> maybe_pluck(req.options["return"])
    {:reply, req.reply_to, item, state}
  end

  defp maybe_match(%{"matches" => matches}=options, item) do
    regex = compile_regex(matches)
    case matches?(item, regex, options["field"]) do
      true -> item
      false -> nil
    end
  end
  defp maybe_match(%{"field" => field}, item) do
    case item[field] do
      nil -> nil
      _ -> item
    end
  end
  defp maybe_match(_, item),
    do: item

  defp maybe_pluck([], _),
    do: []
  defp maybe_pluck(item, nil),
    do: item
  defp maybe_pluck(item, field_string) when is_map(item) do
    return_fields = String.split(field_string, ~r/[\,\s]/, trim: true)
    {new_item, _} = Map.split(item, return_fields)
    new_item
  end
  defp maybe_pluck(item, _),
    do: item

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

  defp matches?(nil, regex),
    do: matches?("", regex)
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

