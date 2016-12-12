defmodule Cog.Commands.User.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "user-list"

  alias Cog.Repository.Users

  @description "List all users."

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user-list must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    rendered = Cog.V1.UserView.render("index.json", %{users: Users.all})
    {:reply, req.reply_to, "user-list", rendered[:users], state}
  end

end
