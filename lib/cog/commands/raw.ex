defmodule Cog.Command.Raw do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle
  alias Cog.Messages.Command

  @description "Show raw output without templating"

  @long_description """
  Even if a template was provided by the previous command, the raw output
  will be returned. Useful as a debugging tool for command authors.
  """

  @examples """
  echo foo | raw
  > {
      "body": [
        "foo"
      ]
    }
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:raw allow"

  def handle_message(%Command{cog_env: nil}=req, state),
    do: {:reply, req.reply_to, "nil", state}
  def handle_message(req, state),
    do: {:reply, req.reply_to, req.cog_env, state}

end
