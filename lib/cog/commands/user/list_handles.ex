defmodule Cog.Commands.User.ListHandles do
  alias Cog.Repository.ChatHandles
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all chat handles attached to users for the active chat adapter.

  USAGE
    user list-handles [FLAGS]

  FLAGS
    -h, --help  Display this usage info
  """

  def list(%{options: %{"help" => true}}, _args),
    do: show_usage
  def list(req, _args) do
    provider_name = req.requestor["provider"]
    handles = ChatHandles.for_provider(provider_name)
    {:ok, "user-list-handles",
     Enum.map(handles,
              &Cog.V1.ChatHandleView.render("show.json", %{chat_handle: &1}))}
  end

end
