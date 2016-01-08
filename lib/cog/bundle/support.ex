defmodule Cog.Bundle.Support do

  use Cog.Queries
  alias Cog.Repo

  @doc """
    Given a permission name, adds the permission to the `site` namespace.
    Example:
    ```
    add_perm_for_site "grant"
    ```
  """
  def add_perm_for_site(name) do
    Cog.Repo.get_by(Cog.Models.Permission.Namespace, name: "site")
    |> Cog.Models.Permission.insert_new(%{name: name})
  end

  @doc """
    Given a group name, adds the group
    Example:
    ```
    add_group "engineering"
    ```
  """
  def add_group(name) do
    %Group{}
    |> Group.changeset(%{name: name})
    |> Repo.insert!
  end

  @doc """
    Given a role name, adds the role
    Example:
    ```
    add_role "dev"
    ```
  """
  def add_role(name) do
    %Role{}
    |> Role.changeset(%{name: name})
    |> Repo.insert!
  end
end
