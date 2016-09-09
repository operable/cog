defmodule Cog.Commands.Sort do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.MemoryClient

  @description "Sort inputs by field"

  @long_description """
  Fields are used to pick which values to sort by. If two keys have the same
  value the values of the next key are compared and so on. If no fields are
  provided, items are intellegently sorted based on their contents.
  """

  @examples """
  seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | sort
  > [{"a": 1}, {"a": 2}, {"a": 3}]

  seed '[{"a": 1}, {"a": 3}, {"a": 2}]' | sort --desc
  > [{"a": 3}, {"a": 2}, {"a": 1}]

  seed '[{"a": 3, "b": 4}, {"a": 1, "b": 4}, {"a": 2, "b": 6}]' | sort b a
  > [{"a": 1, "b": 4}, {"a: 3, "b": 4}, {"a": 2, "b": 6}]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:sort allow"

  option "desc", short: "d", type: "bool", required: false
  option "asc",  short: "a", type: "bool", required: false

  def handle_message(req, state) do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    step  = req.invocation_step
    value = req.cog_env
    opts  = req.options
    args  = req.args

    MemoryClient.accum(root, token, key, value)

    case step do
      step when step in ["first", nil] ->
        {:reply, req.reply_to, nil, state}
      "last" ->
        accumulated_value = MemoryClient.fetch(root, token, key)
        sorted_value = sort_by(accumulated_value, opts, args)
        MemoryClient.delete(root, token, key)
        {:reply, req.reply_to, sorted_value, state}
    end
  end

  defp sort_by(items, %{"desc" => true}, args),
    do: Enum.sort_by(items, &pluck_fields(&1, args), &>=/2)
  defp sort_by(items, _opts, args),
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
