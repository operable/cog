defmodule Cog.V1.ChatHandleControllerTest do
  use Cog.ModelCase
  use Cog.ConnCase

  alias Cog.Models.ChatHandle
  alias Cog.Models.ChatProvider

  @valid_attrs %{handle: "vansterminator",
                 chat_provider: "slack"}

  setup do
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
    provider = Repo.get_by(ChatProvider, name: "slack")

    # Chat handles for our two users
    authed_handle = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "Cogswell",
                                                          "provider_id" => provider.id,
                                                          "user_id" => authed_user.id})
                    |> Repo.insert!
    unauthed_handle = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "supersad",
                                                            "provider_id" => provider.id,
                                                            "user_id" => unauthed_user.id})
                      |> Repo.insert!

    {:ok, [authed: authed_user,
           unauthed: unauthed_user,
           authed_handle: authed_handle,
           unauthed_handle: unauthed_handle,
           provider: provider]}
  end

  test "creates and renders resource when data is valid", params do
    conn = api_request(params.authed, :post, "/v1/users/#{params.authed.id}/chat_handles", body: %{"chat_handle" => @valid_attrs})
    id = json_response(conn, 201)["chat_handle"]["id"]
    assert Repo.get_by(ChatHandle, id: id)
  end

  test "lists all entries on index", params do
    conn = api_request(params.authed, :get, "/v1/chat_handles")
    chat_handles_json = json_response(conn, 200)["chat_handles"]
    assert [%{"id" => params.authed_handle.id,
              "handle" => "Cogswell",
              "user" => %{
                "id" => params.authed.id,
                "email_address" => params.authed.email_address,
                "first_name" => params.authed.first_name,
                "last_name" => params.authed.last_name,
                "username" => params.authed.username
              },
              "chat_provider" => %{"id" => params.provider.id,
                                   "name" => "slack"}},
            %{"id" => params.unauthed_handle.id,
              "handle" => "supersad",
              "user" => %{
                "id" => params.unauthed.id,
                "email_address" => params.unauthed.email_address,
                "first_name" => params.unauthed.first_name,
                "last_name" => params.unauthed.last_name,
                "username" => params.unauthed.username
              },
              "chat_provider" => %{"id" => params.provider.id,
                                   "name" => "slack"}}] == chat_handles_json
  end

  test "lists all entries for a specified user", params do
    conn = api_request(params.authed, :get, "/v1/users/#{params.authed.id}/chat_handles")
    chat_handles_json = json_response(conn, 200)["chat_handles"]
    assert [%{"id" => params.authed_handle.id,
              "handle" => "Cogswell",
              "user" => %{
                "id" => params.authed.id,
                "email_address" => params.authed.email_address,
                "first_name" => params.authed.first_name,
                "last_name" => params.authed.last_name,
                "username" => params.authed.username
              },
              "chat_provider" => %{"id" => params.provider.id,
                                   "name" => "slack"}}] == chat_handles_json
  end

  test "deletes an entry", params do
    delete_test = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "DeleteTest",
                                                        "provider_id" => params.provider.id,
                                                        "user_id" => params.authed.id})
                  |> Repo.insert!
    conn = api_request(params.authed, :delete, "/v1/chat_handles/#{delete_test.id}")
    assert response(conn, 204)
    refute Repo.get(ChatHandle, delete_test.id)
  end

  test "updates and renders chosen resource when data is valid", params do
    update_test = ChatHandle.changeset(%ChatHandle{}, %{"handle" => "UpdateTest",
                                                        "provider_id" => params.provider.id,
                                                        "user_id" => params.authed.id})
                  |> Repo.insert!
    conn = api_request(params.authed, :put, "/v1/chat_handles/#{update_test.id}",
                       body: %{"chat_handle" => %{
                                 "chat_provider" => "slack",
                                 "handle" => "NewUpdateTest"}})
    chat_handle_json = json_response(conn, 200)["chat_handle"]
    assert chat_handle_json == %{"id" => update_test.id,
                                 "chat_provider" => %{"id" => params.provider.id,
                                                      "name" => "slack"},
                                 "handle" => "NewUpdateTest",
                                 "user" => %{
                                   "id" => params.authed.id,
                                   "email_address" => params.authed.email_address,
                                   "first_name" => params.authed.first_name,
                                   "last_name" => params.authed.last_name,
                                   "username" => params.authed.username
                                 }}
  end


end
