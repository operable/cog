defmodule Cog.Commands.AbortWhen do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "abort-when"

  @description "Aborts pipeline when argument evaluates to truthy"

  @arguments "value"

  @default_message "Pipeline aborted"

  option "message", short: "m", type: "string", required: false,
    description: "Message sent when pipeline is aborted"

  # Allow any user to run
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:abort-when allow"

  def handle_message(req, state) do
    case eval_args(req.args) do
      true ->
        {:abort, req.reply_to, Map.get(req.options, "message", @default_message), state}
      false ->
        {:reply, req.reply_to, req.cog_env, state}
    end
  end

  defp eval_args([n|_]) when n > 0, do: true
  defp eval_args([true|_]), do: true
  defp eval_args(_), do: false

end
