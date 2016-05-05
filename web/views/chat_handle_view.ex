defmodule Cog.V1.ChatHandleView do
  use Cog.Web, :view

  def render("show.json", %{chat_handle: chat_handle}) do
    %{id: chat_handle.id,
      handle: chat_handle.handle,
      chat_provider: render_one(
        chat_handle.chat_provider,
        Cog.V1.ChatProviderView,
        "show.json"
      )}
  end
end
