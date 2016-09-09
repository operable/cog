defmodule Cog.Commands.Sleep do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.MemoryClient

  @description "Pauses pipeline execution for a given number of seconds"

  @long_description """
  Mainly useful for debugging and testing.
  """

  @examples """
  sleep 2400 | echo "Lasagna is done cooking!" > me
  > Lasagna is done cooking!
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:sleep allow"

  def handle_message(%{args: [seconds]} = req, state) when is_integer(seconds) do
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
        MemoryClient.delete(root, token, key)
        :timer.sleep(seconds * 1000)
        {:reply, req.reply_to, accumulated_value, state}
    end
  end

  def handle_message(%{args: []} = req, state),
    do: {:error, req.reply_to, "Must specify a duration", state}
  def handle_message(req, state),
    do: {:error, req.reply_to, "Must specify a only one duration", state}
end
