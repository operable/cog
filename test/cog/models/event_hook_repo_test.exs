defmodule Cog.Models.EventHookRepoTest do
  @moduledoc """
  Test side-effecting EventHook model code
  """

  use Cog.ModelCase, async: false
  alias Cog.Models.EventHook

  @valid_attrs %{name: "echo_message",
                 pipeline: "echo $body.message > chat://#general",
                 as_user: "marvin"}

  test "hook names are unique" do
    assert %EventHook{} = EventHook.changeset(%EventHook{}, @valid_attrs) |> Repo.insert!
    {:error, changeset} = EventHook.changeset(%EventHook{}, @valid_attrs) |> Repo.insert
    assert {:name, "has already been taken"} in changeset.errors
  end

end
