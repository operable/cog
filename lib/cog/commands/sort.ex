defmodule Cog.Commands.Sort do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, execution: :once

  @moduledoc """
  Sorts the given inputs.

  Examples
      @bot #{Cog.embedded_bundle}:sort 3 2 1 5 4
      > [1, 2, 3, 4, 5]
      @bot #{Cog.embedded_bundle}:sort --asc 4.5 1.8 0.032 0.6 1.5 0.4
      > [0.032, 0.4, 0.6, 1.5, 1.8, 4.5]
      @bot #{Cog.embedded_bundle}:sort --desc Life is 10 percent what happens to us and 90% how we react to it
      > [what, we, us, to, to, react, percent, it, is, how, happens, and, Life, %, 90, 10]
      @bot #{Cog.embedded_bundle}:rules --for-command=rules| sort --field=rule
      > {
  "rule": "when command is operable:permissions with option[user] == /.*/ must have operable:manage_users",
  "id": "12345678-abcd-efgh-ijkl-0987654321ab",
  "command": "operable:permissions"
}
{
  "rule": "when command is operable:permissions with option[role] == /.*/ must have operable:manage_roles",
  "id": "87654321-mnop-qrst-uvwx-0123456789ab",
  "command": "operable:permissions"
}
{
  "rule": "when command is operable:permissions with option[group] == /.*/ must have operable:manage_groups",
  "id": "24680135-azby-cxdw-evfu-ab0123456789",
  "command": "operable:permissions"
}
  """
  option "asc", type: "bool", required: false
  option "desc", type: "bool", required: false
  option "field", type: "string", required: false

  def handle_message(req, state) do
    args = case req.cog_env do
             [map] when map == %{} ->
               req.args
             arg ->
               arg
           end

    options = get_options(req.options)
    {:reply, req.reply_to, sort_items(options, args), state}
  end

  defp get_options(options) when is_list(options) do
    [opt | _] = options
    opt
  end
  defp get_options(options), do: options

  defp sort_items(options, items) do
    case options do
      %{"desc" => true, "field" => field} ->
        Enum.sort_by(items, &field_func(&1, field), &>=/2)
      %{"desc" => true} ->
        Enum.sort(items, &(&1 > &2))
      %{"field" => field} ->
        Enum.sort_by(items, &field_func(&1, field))
      _ ->
        Enum.sort(items)
    end
  end

  defp field_func(item, field) do
    case item[field] do
      nil -> item
      value -> value
    end
  end
end
