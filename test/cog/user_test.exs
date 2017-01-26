defmodule UserTest do
  use Cog.ModelCase

  alias Cog.Models.User
  alias Cog.Repo

  setup do
    user = user("cog")
    {:ok, [user: user,
           role: role("create"),
           permission: permission("test:creation"),
           group: group("test_group")]}
  end

  @valid_attrs %{username: "alien_killer", first_name: "Ripley", last_name: "Alien",
                 email_address: "ripley@cog.test", password: "xenomorph"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "password is required on insert" do
    changeset = %User{} |> User.changeset(%{"username" => "operator",
                                            "first_name" => "Operator",
                                            "last_name" => "McOperator",
                                            "email_address" => "operator@operable.io"})
    refute changeset.valid?
    assert {:password, {"can't be blank", []}} in changeset.errors
  end

  test "password is stored as a digest" do
    password = "sooperseekritdonttellanyoneshhhhhhh"

    %User{id: id} = %User{}
    |> User.changeset(%{"username" => "operator",
                        "first_name" => "Operator",
                        "last_name" => "McOperator",
                        "email_address" => "operator@operable.io",
                        "password" => password})
    |> Repo.insert!

    retrieved = Repo.get_by(User, id: id)
    refute retrieved.password
    assert String.starts_with?(retrieved.password_digest, "$2")
  end

  test "updating an existing user doesn't require a password" do
    password = "sooperseekritdonttellanyoneshhhhhhh"

    # Create a new user and grab its ID
    %User{id: id, password_digest: digest} = %User{}
    |> User.changeset(%{"username" => "operator",
                        "first_name" => "Operator",
                        "last_name" => "McOperator",
                        "email_address" => "operator@operable.io",
                        "password" => password})
    |> Repo.insert!

    # Update the user, but don't change the password
    updated = update_user(id, %{"last_name" => "von Operator"})

    # Ensure the password info remains the same
    assert "von Operator" = updated.last_name
    refute updated.password
    assert ^digest = updated.password_digest
  end

  test "updating a password updates the digest value instead" do
    old_password = "sooperseekritdonttellanyoneshhhhhhh"

    %User{id: id, password_digest: old_digest} = %User{}
    |> User.changeset(%{"username" => "operator",
                        "first_name" => "Operator",
                        "last_name" => "McOperator",
                        "email_address" => "operator@operable.io",
                        "password" => old_password})
    |> Repo.insert!

    new_password = "LookUponMyPassword,YeMighty,AndDespair!"
    updated = update_user(id, %{"password" => new_password})

    assert old_digest != updated.password_digest
    assert String.starts_with?(updated.password_digest, "$2")
  end

  test "deleting a user belonging to a group", %{user: user, group: group} do
    :ok = Groupable.add_to(user, group)
    changeset = User.changeset(user, %{})
    assert {:error, changeset} = Repo.delete(changeset)
    assert [id: {"cannot delete user that is a member of a group", []}] = changeset.errors
  end

  @doc """
  Given an id and a hash of changes, update the user with
  that id and return the resulting User struct after retrieving from
  the database.

  Any virtual fields (lookin' at you, `password`) will thus be empty
  in the returned struct.
  """
  def update_user(id, changes) do
    User
    |> Repo.get_by(id: id)
    |> User.changeset(changes)
    |> Repo.update!

    Repo.get_by(User, id: id)
  end

end
