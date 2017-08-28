defmodule Cog.Commands.Count do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.MemoryClient

  @description "Return the count of the values in the input list"

  @arguments "[path]"

  @examples """
  seed '[{"a": 2}, {"a": -1}, {"b": 3}]' | count
  > 3

  seed '[{"a": 2}, {"a": -1}, {"b": 3}]' | count a
  > 2

  seed '[{"a": {"b": 2}}, {"b": {"b": -1}}, {"a": {"c": 3}}]' | count a.b
  > 1
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:count allow"

  def handle_message(req, state) do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    step  = req.invocation_step
    value = req.cog_env
    args  = req.args

    MemoryClient.accum(root, token, key, value)

    case step do
      step when step in ["first", "", nil] ->
        {:reply, req.reply_to, nil, state}
      "last" ->
        accumulated_value = MemoryClient.fetch(root, token, key)
        {:ok, value} = count_by(accumulated_value, args)
        MemoryClient.delete(root, token, key)
        {:reply, req.reply_to, value, state}
    end
  end

  defp count_by([%{}], []),
    do: {:ok, 0}
  defp count_by(items, []),
    do: {:ok, Enum.count(items)}
  defp count_by(items, [path]) do
    path_list = path_to_list(path)

    case bad_path(items, path_list) do
      true ->
        {:ok, 0}
      false ->
        count = Enum.count(items, &get_in(&1, path_list))
        {:ok, count}
    end
  end

  defp bad_path(items, path_list) do
    Enum.all?(items, fn item ->
      item
      |> get_in(path_list)
      |> is_nil
    end)
  end

  defp path_to_list(path) do
    String.split(path, ".")
  end
end
