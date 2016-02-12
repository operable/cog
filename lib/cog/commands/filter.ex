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
  option "return", type: "list", required: false

  def handle_message(req, state) do
    %{cog_env: item, options: options} = req

    result = item
    |> maybe_filter(options)
    |> maybe_pluck(options)

    {:reply, req.reply_to, result, state}
  end

  defp maybe_filter(item, %{"field" => field, "matches" => matches}) do
    match = with {:ok, field} <- Access.fetch(item, field),
      regex = compile_regex(matches),
      field_string = to_string(field),
      do: String.match?(field_string, regex)

    case match do
      true ->
        item
      _ ->
        nil
    end
  end
  defp maybe_filter(item, %{"field" => field}) do
    case Access.fetch(item, field) do
      {:ok, _} ->
        item
      :error ->
        nil
    end
  end
  defp maybe_filter(item, _),
    do: item

  defp maybe_pluck(item, %{"return" => []}),
    do: item
  defp maybe_pluck(item, %{"return" => fields}) when is_map(item),
    do: Map.take(item, fields)
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
end
