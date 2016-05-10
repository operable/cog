defmodule Cog.V1.ChatProviderView do
  use Cog.Web, :view

  def render("show.json", %{chat_provider: chat_provider}) do
    %{name: chat_provider.name}
  end
end
