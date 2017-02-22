defmodule Cog.Models.ChatHandleRepoTest do
  @moduledoc """
  Test side-effecting ChatHandle model code
  """
  use Cog.ModelCase, async: false
  alias Cog.Models.ChatHandle

  test "chat handles are unique for a provider" do
    first = user("first_user")
    second = user("second_user")


    attrs = %{"handle" => "test_handle",
              "provider_id" => 1,
              "chat_provider_user_id" => "my_slack_id"}


    assert %ChatHandle{} = %ChatHandle{}
    |> ChatHandle.changeset(Map.merge(attrs, %{"user_id" => first.id}))
    |> Repo.insert!

    {:error, changeset} = %ChatHandle{}
    |> ChatHandle.changeset(Map.merge(attrs, %{"user_id" => second.id}))
    |> Repo.insert

    assert {:handle, {"Another user has claimed this chat handle", []}} in changeset.errors
  end

end
