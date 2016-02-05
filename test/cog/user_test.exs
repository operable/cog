defmodule UserTest do
  use Cog.ModelCase
  use Cog.Models
  alias Cog.Repo

  setup do
    user = user("cog")
    {:ok, [user: user,
           role: role("create"),
           permission: permission("test:creation")]}
  end

  test "retrieving user includes chat handles", %{user: user} do
    # with_chat_handle_for registers a handle that is the same as the username
    user |> with_chat_handle_for("slack")
    found_user = Repo.one!(Cog.Queries.User.for_handle(user.username, "slack"))

    assert(found_user.id == user.id)

    assert(length(found_user.chat_handles) == 1)
    retrieved_handle = Enum.at(found_user.chat_handles, 0)
    assert(retrieved_handle.handle == user.username)
  end

  test "permissions may be granted directly to users", %{user: user, permission: permission} do
    :ok = Permittable.grant_to(user, permission)
    assert_permission_is_granted(user, permission)
  end

  test "granting a permission to a user is idempotent", %{user: user, permission: permission} do
    :ok = Permittable.grant_to(user, permission)
    assert(:ok = Permittable.grant_to(user, permission))
  end

  test "roles may be granted directly to a user", %{user: user, role: role} do
    :ok = Permittable.grant_to(user, role)
    assert_role_was_granted(user, role)
  end

  test "granting a role to a user is idempotent", %{user: user, role: role} do
    :ok = Permittable.grant_to(user, role)
    assert(:ok = Permittable.grant_to(user, role))
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
    assert {:password, "can't be blank"} in changeset.errors
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
