defmodule Cog.Support.TestCommands.BadTemplate do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, name: "bad-template"

  rule "when command is #{Cog.embedded_bundle}:bad-template allow"

  def handle_message(req, state) do
    {:reply, req.reply_to, "badtemplate", %{bad: %{foo: "bar"}}, state}
  end
end
