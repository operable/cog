defmodule Cog.Support.TestCommands.RequiredOptTestCommand do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle, name: "req-opt"

  @description "description"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:req-opt allow"

  option "req", type: "string", required: true

  def handle_message(req, state) do
    {:reply, req.reply_to, "req-opt response", state}
  end
end
