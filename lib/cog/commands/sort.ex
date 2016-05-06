defmodule Cog.Commands.Sort do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  alias Cog.Command.Service.MemoryClient

  @moduledoc """
  Sorts the given list of input in ascending order by default.

  ## Usage

    sort [options] [fields...]

    Fields are used to pick which values to sort by. If two keys have the same
    value the values of the next key are compared and so on. If no fields are
    provided, items are intellegently sorted based on their contents.

  ## Options

    --asc, -a    sort in ascending order
    --desc, -d   sort in descending order

  ## Examples
    @cog seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | sort
    > [{"a": 1}, {"a": 2}, {"a": 3}]

    @cog seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | sort --desc
    > [{"a": 3}, {"a": 2}, {"a": 1}]

    @cog seed '[{"a": 3, "b": 4}, {"a": 1, "b": 4}, {"a": 2, "b": 6}]' | sort b a
    > [{"a": 1, "b": 4}, {"a: 3, "b": 4}, {"a": 2, "b": 6}]
  """

  rule "when command is #{Cog.embedded_bundle}:sort allow"

  option "desc", short: "d", type: "bool", required: false
  option "asc",  short: "a", type: "bool", required: false

  def handle_message(%{invocation_step: step} = req, state) when step in ["first", nil] do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    value = req.cog_env

    MemoryClient.accum(root, token, key, value)

    {:reply, req.reply_to, nil, state}
  end

  def handle_message(%{invocation_step: "last"} = req, state) do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    value = req.cog_env

    options = req.options
    args    = req.args

    accumulated_value = MemoryClient.fetch(root, token, key)
    sorted_value = sort_by(accumulated_value ++ [value], options, args)
    MemoryClient.delete(root, token, key)

    {:reply, req.reply_to, sorted_value, state}
  end

  defp sort_by(items, %{"desc" => true}, args),
    do: Enum.sort_by(items, &pluck_fields(&1, args), &>=/2)
  defp sort_by(items, _options, args),
    do: Enum.sort_by(items, &pluck_fields(&1, args))

  defp pluck_fields(item, []),
    do: item
  defp pluck_fields(item, fields) do
    values = Enum.map(fields, &Map.get(item, &1))

    case Enum.reject(values, &is_nil/1) do
      [] ->
        item
      _ ->
        values
    end
  end
end
