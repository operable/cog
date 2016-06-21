defmodule Cog.Repository.ChatHandles do

  alias Cog.Repo
  alias Cog.Models.User
  alias Cog.Models.ChatHandle
  alias Cog.Models.ChatProvider

  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  @doc """
  Sets the user's chat handle for the given provider. Each Cog user
  can only have a single chat handle per provider.
  """
  def set_handle(%User{id: user_id}, provider_name, handle) do
    Repo.transaction(fn() ->
      case chat_handle_params(provider_name, handle, user_id) do
        {:ok, params} ->

          result = user_id
          |> find_handle_for(provider_name)
          |> ChatHandle.changeset(params)
          |> Repo.insert_or_update

          case result do
            {:ok, chat_handle} ->
              Repo.preload(chat_handle, [:chat_provider, :user])
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  def remove_handle(%User{id: user_id}, provider_name) do
    case Cog.Repo.one(handle_query(user_id, provider_name)) do
      nil ->
        :ok
      %ChatHandle{}=handle ->
        Repo.delete!(handle)
        :ok
    end
  end

  ########################################################################

  # As part of our "upsert" logic, we need to determine if the user
  # already has a handle for this provider or not. If so, return it;
  # otherwise, return an empty ChatHandle for further processing.
  defp find_handle_for(user_id, provider_name) do
    case Cog.Repo.one(handle_query(user_id, provider_name)) do
      %ChatHandle{}=handle ->
        handle
      nil ->
        %ChatHandle{}
    end
  end

  # Find the one handle the user has for the provider, if any
  defp handle_query(user_id, provider_name) do
    from ch in ChatHandle,
    join: p in assoc(ch, :chat_provider),
    where: ch.user_id == ^user_id,
    where: p.name == ^provider_name
  end

  # We track the chat provider's "internal user ID" for a given
  # handle. Thus, when we create or change the handle, we need to
  # consult the chat provider to obtain this information.
  #
  # One side effect of how things are currently structured is that we
  # only allow handles to be created or edited if the currently
  # running chat adapter is the one for the chat provider in
  # question. That is, if you're running Cog with the Slack adapter,
  # you can _only_ create or update Slack chat handles.
  defp chat_handle_params(provider_name, handle, user_id) do
    provider_name = String.downcase(provider_name)
    {:ok, adapter} = Cog.chat_adapter_module
    if provider_name == adapter.name do
      case Repo.get_by(ChatProvider, name: provider_name) do
        %ChatProvider{id: provider_id} ->
          case adapter.lookup_user(handle) do
            {:ok, %{id: chat_provider_user_id, handle: normalized_handle}} ->
              {:ok, %{"handle" => normalized_handle,
                      "provider_id" => provider_id,
                      "user_id" => user_id,
                      "chat_provider_user_id" => chat_provider_user_id}}
            {:error, _} ->
              {:error, :invalid_handle}
          end
        nil ->
          {:error, :invalid_provider}
      end
    else
      {:error, :adapter_not_running}
    end
  end

end
