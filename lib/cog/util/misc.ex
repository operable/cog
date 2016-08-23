defmodule Cog.Util.Misc do

  @doc "The name of the embedded command bundle."
  def embedded_bundle, do: "operable"

  @doc "The name of the site namespace."
  def site_namespace, do: "site"

  @doc "The name of the admin role."
  def admin_role, do: "cog-admin"

  @doc "The name of the admin group."
  def admin_group, do: "cog-admin"

  ########################################################################
  # Adapter Resolution Functions

  @doc """
  Returns the name of the currently configured chat provider module, if found
  """
  def chat_adapter_module do
    # TODO: really "chat provider name"
    config = Application.fetch_env!(:cog, Cog.Chat.Adapter)
    case Keyword.fetch(config, :chat) do
      {:ok, name} when is_atom(name) ->
        {:ok, Atom.to_string(name)}
      :error ->
        {:error, :no_chat_provider_declared}
    end
  end

  ########################################################################

end
