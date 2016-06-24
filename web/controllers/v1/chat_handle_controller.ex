defmodule Cog.V1.ChatHandleController do
  use Cog.Web, :controller

  alias Cog.Models.EctoJson
  alias Cog.Models.ChatHandle
  alias Cog.Models.User

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, [permission: "#{Cog.embedded_bundle}:manage_users",
                                allow_self_updates: [:upsert]]

  plug :scrub_params, "chat_handle" when action in [:create, :update]

  def index(conn, _params) do
    chat_handles = ChatHandle
    |> Repo.all
    |> Repo.preload([:chat_provider, :user])

    json(conn, EctoJson.render(chat_handles, envelope: :chat_handles))
  end

  def upsert(conn, %{"chat_handle" => %{"handle" => handle,
                                        "chat_provider" => provider_name},
                     "id" => user_id}) do
    case Cog.Repository.ChatHandles.set_handle(%User{id: user_id}, provider_name, handle) do
      {:ok, chat_handle} ->
        conn
        |> put_status(:created)
        |> json(EctoJson.render(chat_handle, envelope: :chat_handle, policy: :detail))
      {:error, %Ecto.Changeset{}=changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ChangesetView, "error.json", changeset: changeset)
      {:error, :invalid_provider} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ErrorView, "422.json", %{error: "Provider '#{provider_name}' not found"})
      {:error, :invalid_handle} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ErrorView, "422.json", %{error: "User with handle '#{handle}' not found"})
      {:error, :adapter_not_running} ->
        {:ok, adapter} = Cog.chat_adapter_module
        conn
        |> put_status(:unprocessable_entity)
        |> render(Cog.ErrorView, "422.json", %{error: "Currently, you can only set chat handles for the configured chat adapter, which handles '#{adapter.name}'. You requested a chat handle for '#{provider_name}'"})
    end
  end

  def delete(conn, %{"id" => id}) do
    Repo.get!(ChatHandle, id)
    |> Repo.delete!
    send_resp(conn, :no_content, "")
  end

end
