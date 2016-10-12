defmodule Cog.Commands.Unique do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.MemoryClient

  @description "Removes all duplicate values from the input"

  @examples """
  seed '[{"a": 1}, {"a": 3}, {"a": 1}]' | unique
  > [{"a": 1}, {"a": 3}]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:unique allow"

  def handle_message(req, state) do
    root  = req.services_root
    token = req.service_token
    key   = req.invocation_id
    step  = req.invocation_step
    value = req.cog_env

    MemoryClient.accum(root, token, key, value)

    case step do
      step when step in ["first", nil] ->
        {:reply, req.reply_to, nil, state}
      "last" ->
        accumulated_value = MemoryClient.fetch(root, token, key)
        unique_values = Enum.uniq(accumulated_value)
        MemoryClient.delete(root, token, key)
        {:reply, req.reply_to, unique_values, state}
    end
  end
end
