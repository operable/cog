defmodule Cog.Commands.Max do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.MemoryClient

  @description "Return the maximum value in the input list"

  @arguments "[path]"

  @examples """
  seed '[{"a": 2}, {"a": -1}, {"a": 3}]' | max
  > {"a": 3}

  seed '[{"a": 2}, {"a": -1}, {"a": 3}]' | max a
  > {"a": 3}

  seed '[{"a": {"b": 2}}, {"a": {"b": -1}}, {"a": {"b": 3}}]' | max a.b
  > {"a": {"b": 3}}
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:max allow"

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
        max_value = max_by(accumulated_value, args)
        MemoryClient.delete(root, token, key)

        case max_value do
          {:ok, value} ->
            {:reply, req.reply_to, value, state}
          {:error, error} ->
            {:error, req.reply_to, error, state}
        end
    end
  end

  defp max_by(items, []),
    do: {:ok, Enum.max(items)}
  defp max_by(items, [path]) do
    path_list = path_to_list(path)

    case bad_path(items, path_list) do
      true ->
        {:error, "The path provided does not exist"}
      false ->
        max_item = Enum.max_by(items, &get_in(&1, path_list))
        {:ok, max_item}
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
