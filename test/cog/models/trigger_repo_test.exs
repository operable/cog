defmodule Cog.Models.TriggerRepoTest do
  @moduledoc """
  Test side-effecting Trigger model code
  """

  use Cog.ModelCase, async: false
  alias Cog.Models.Trigger

  @valid_attrs %{name: "echo_message",
                 pipeline: "echo $body.message > chat://#general",
                 as_user: "marvin"}

  test "trigger names are unique" do
    assert %Trigger{} = Trigger.changeset(%Trigger{}, @valid_attrs) |> Repo.insert!
    {:error, changeset} = Trigger.changeset(%Trigger{}, @valid_attrs) |> Repo.insert
    assert {:name, "has already been taken"} in changeset.errors
  end

end
