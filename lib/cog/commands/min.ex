defmodule Cog.Commands.Min do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.MemoryClient

  @description "Return the minimum value in the input list"

  @arguments "[path]"

  @examples """
  seed '[{"a": 2}, {"a": -1}, {"a": 3}]' | min
  > {"a": -1}

  seed '[{"a": 2}, {"a": -1}, {"a": 3}]' | min a
  > {"a": -1}

  seed '[{"a": {"b": 2}}, {"a": {"b": -1}}, {"a": {"b": 3}}]' | min a.b
  > {"a": {"b": -1}}
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:min allow"

  def handle_message(req, state) do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    step  = req.invocation_step
    value = req.cog_env
    args  = req.args

    MemoryClient.accum(root, token, key, value)

    case step do
      step when step in ["first", nil] ->
        {:reply, req.reply_to, nil, state}
      "last" ->
        accumulated_value = MemoryClient.fetch(root, token, key)
        min_value = min_by(accumulated_value, args)
        MemoryClient.delete(root, token, key)

        case min_value do
          {:ok, value} ->
            {:reply, req.reply_to, value, state}
          {:error, error} ->
            {:error, req.reply_to, error, state}
        end
    end
  end

  defp min_by(items, []),
    do: {:ok, Enum.min(items)}
  defp min_by(items, [path]) do
    path_list = path_to_list(path)

    case bad_path(items, path_list) do
      true ->
        {:error, "The path provided does not exist"}
      false ->
        min_item = Enum.min_by(items, &get_in(&1, path_list))
        {:ok, min_item}
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
