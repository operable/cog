defmodule Cog.Support.TestCommands.TypesTestCommand do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle, name: "type-test"

  @description "description"

  option "string", type: "string", required: false
  option "bool", type: "bool", required: false
  option "int", type: "int", required: false
  option "float", type: "float", required: false
  option "incr", type: "incr", required: false

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:type-test allow"

  def handle_message(req, state) do
    {:reply, req.reply_to, "type-test response", state}
  end
end
