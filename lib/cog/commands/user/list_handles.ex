defmodule Cog.Commands.User.ListHandles do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "user-list-handles"

  alias Cog.Repository.ChatHandles

  @description "List all chat handles attached to users for the active chat provider."

  @output_description "Returns the user with their attached handle."

  @output_example """
  [
    {
      "username": "bob",
      "id": "00000000-0000-0000-0000-000000000000",
      "handle": "mrbob",
      "chat_provider": {
        "name": "slack"
      }
    }
  ]
  """

  permission "manage_users"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user-list-handles must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    data = req.requestor.provider
           |> ChatHandles.for_provider()
           |> Enum.map(&Cog.V1.ChatHandleView.render("show.json", %{chat_handle: &1}))
    {:reply, req.reply_to, "user-list-handles", data, state}
  end

end
