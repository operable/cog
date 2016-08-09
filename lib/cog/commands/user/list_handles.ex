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
  def list(_req, _args) do
    {:ok, adapter} = Cog.chat_adapter_module
    handles = ChatHandles.for_provider(adapter.name)
    {:ok, "user-list-handles",
     Enum.map(handles,
              &Cog.V1.ChatHandleView.render("show.json", %{chat_handle: &1}))}
  end

end
