defmodule Cog.Support.TestCommands.TypesTestCommand do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, name: "type-test"

  option "string", type: "string", required: false
  option "bool", type: "bool", required: false
  option "int", type: "int", required: false
  option "float", type: "float", required: false
  option "incr", type: "incr", required: false

  def handle_message(req, state) do
    {:reply, req.reply_to, "type-test response", state}
  end
end
