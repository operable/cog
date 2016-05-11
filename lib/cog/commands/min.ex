defmodule Cog.Commands.Min do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.embedded_bundle

  alias Cog.Command.Service.MemoryClient
  require Logger

  @moduledoc """
  Finds the minimum value in the input list.

  USAGE
    min [path]

  ARGS
    path  JSON path used in determining the minimum

  EXAMPLES
    seed '[{"a": 2}, {"a": -1}, {"a": 3}]' | min
    > {"a": -1}

    seed '[{"a": 2}, {"a": -1}, {"a": 3}]' | min a
    > {"a": -1}

    seed '[{"a": {"b": 2}}, {"a": {"b": -1}}, {"a": {"b": 3}}]' | min a.b
    > {"a": {"b": -1}}
  """

  rule "when command is #{Cog.embedded_bundle}:min allow"

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
        {:reply, req.reply_to, min_value, state}
    end
  end

  defp min_by(items, []),
    do: Enum.min(items)
  defp min_by(items, [path]) do
    path_list = path_to_list(path)
    Enum.min_by(items, &get_in(&1, path_list))
  end

  defp path_to_list(path) do
    String.split(path, ".")
  end
end
