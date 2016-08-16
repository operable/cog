defmodule Cog.V1.ChatHandleControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.ChatHandle
  alias Cog.Models.ChatProvider

  @valid_attrs %{handle: "vansterminator",
                 chat_provider: "test"}

  setup context do
    # Requests handled by the role controller require this permission
    required_permission = permission("#{Cog.embedded_bundle}:manage_users")

    # This user will be used to test the normal operation of the controller
    authed_user = user("cog")
    |> with_token
    |> with_permission(required_permission)

    # This user will be used to verify that the above permission is
    # indeed required for requests
    unauthed_user = user("sadpanda") |> with_token

    # Provider
    provider = Repo.get_by(ChatProvider, name: "test")

    if context[:create_handles] do
      # Chat handles for our two users
      authed_handle = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "Cogswell",
                                                            "provider_id" => provider.id,
                                                            "user_id" => authed_user.id,
                                                            "chat_provider_user_id" => "U024BE7LH"})
      |> Repo.insert!
      unauthed_handle = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "supersad",
                                                              "provider_id" => provider.id,
                                                              "user_id" => unauthed_user.id,
                                                              "chat_provider_user_id" => "U024BE7LI"})
      |> Repo.insert!

      {:ok, [authed: authed_user,
             unauthed: unauthed_user,
             authed_handle: authed_handle,
             unauthed_handle: unauthed_handle,
             provider: provider]}
    else
      {:ok, [authed: authed_user,
             unauthed: unauthed_user,
             provider: provider]}
    end
  end

  test "users can update their own chat handles even if they aren't authorized", params do
    conn = api_request(params.unauthed, :post, "/v1/users/#{params.unauthed.id}/chat_handles", body: %{"chat_handle" => @valid_attrs})
    id = json_response(conn, 201)["chat_handle"]["id"]
    assert Repo.get_by(ChatHandle, id: id)
  end

  test "creates and renders resource when data is valid", params do
    conn = api_request(params.authed, :post, "/v1/users/#{params.authed.id}/chat_handles", body: %{"chat_handle" => @valid_attrs})
    id = json_response(conn, 201)["chat_handle"]["id"]
    assert Repo.get_by(ChatHandle, id: id)
  end

  test "fails if chat adapter for provider is not running", params do
    chat_provider = "slack"
    {:ok, chat} = Cog.chat_adapter_module
    refute chat_provider == chat

    conn = api_request(params.authed,
                       :post, "/v1/users/#{params.authed.id}/chat_handles",
                       body: %{"chat_handle" => %{handle: "badnews",
                                                  chat_provider: "slack"}})
    assert json_response(conn, 422)["errors"]
  end

  @tag :create_handles
  test "lists all entries on index", params do
    conn = api_request(params.authed, :get, "/v1/chat_handles")
    chat_handles_json = json_response(conn, 200)["chat_handles"]
    assert [%{"id" => params.authed_handle.id,
              "handle" => "Cogswell",
              "chat_provider_user_id" => "U024BE7LH",
              "user" => %{
                "id" => params.authed.id,
                "email_address" => params.authed.email_address,
                "first_name" => params.authed.first_name,
                "last_name" => params.authed.last_name,
                "username" => params.authed.username
              },
              "chat_provider" => %{"id" => params.provider.id,
                                   "name" => "test"}},
            %{"id" => params.unauthed_handle.id,
              "handle" => "supersad",
              "chat_provider_user_id" => "U024BE7LI",
              "user" => %{
                "id" => params.unauthed.id,
                "email_address" => params.unauthed.email_address,
                "first_name" => params.unauthed.first_name,
                "last_name" => params.unauthed.last_name,
                "username" => params.unauthed.username
              },
              "chat_provider" => %{"id" => params.provider.id,
                                   "name" => "test"}}] == chat_handles_json
  end

  test "deletes an entry", params do
    delete_test = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "DeleteTest",
                                                        "provider_id" => params.provider.id,
                                                        "user_id" => params.authed.id,
                                                        "chat_provider_user_id" => "U024BE7LJ"})
                  |> Repo.insert!
    conn = api_request(params.authed, :delete, "/v1/chat_handles/#{delete_test.id}")
    assert response(conn, 204)
    refute Repo.get(ChatHandle, delete_test.id)
  end

  test "updates and renders chosen resource when data is valid", params do
    update_test = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "UpdateTest",
                                                        "provider_id" => params.provider.id,
                                                        "user_id" => params.authed.id,
                                                        "chat_provider_user_id" => "U024BE7LK"})
                  |> Repo.insert!
    conn = api_request(params.authed, :post, "/v1/users/#{params.authed.id}/chat_handles",
                       body: %{"chat_handle" => %{
                                "chat_provider" => "test",
                                "handle" => "updated-user"}})
    chat_handle_json = json_response(conn, 201)["chat_handle"]
    assert chat_handle_json == %{"id" => update_test.id,
                                 "chat_provider" => %{"id" => params.provider.id,
                                                      "name" => "test"},
                                 "handle" => "updated-user",
                                 "chat_provider_user_id" => "U024BE7LK",
                                 "user" => %{
                                   "id" => params.authed.id,
                                   "email_address" => params.authed.email_address,
                                   "first_name" => params.authed.first_name,
                                   "last_name" => params.authed.last_name,
                                   "username" => params.authed.username
                                 }}
  end


end
