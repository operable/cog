defmodule Cog.Models.Role do
  use Cog.Model
  use Cog.Models.EctoJson

  alias Ecto.Changeset

  schema "roles" do
    field :name, :string

    has_many :user_grants, Cog.Models.UserRole
    has_many :group_grants, Cog.Models.GroupRole

    has_many :permission_grants, Cog.Models.RolePermission
    has_many :permissions, through: [:permission_grants, :permission]
  end

  summary_fields [:id, :name, :permissions]
  detail_fields [:id, :name, :permissions]

  @required_fields ~w(name)
  @optional_fields ~w()

  @doc """
  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model), do: changeset(model, :empty)

  @doc """
  Creates a changeset based on the `model` to validate a delete
  action.
  """
  def changeset(model, :delete) do
    %{Changeset.change(model) | action: :delete}
    |> protect_admin_role

  end

  @doc """
  Creates a changeset based on the `model` and `params`.
  """
  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> protect_admin_role
    |> unique_constraint(:name)
  end

  defp protect_admin_role(%Changeset{data: data}=changeset) do
    if data.name == Cog.admin_role do
      changeset
      |> add_error(:name, "admin role may not be modified")
    else
      changeset
    end
  end

end

defimpl Permittable, for: Cog.Models.Role do
  alias Cog.Repo
  alias Cog.Models.JoinTable
  alias Cog.Models.Bundle

  def grant_to(role, permission),
  do: JoinTable.associate(role, permission)

  def revoke_from(role, permission) do
    bundle = Repo.get(Bundle, permission.bundle_id)
    if role.name == Cog.admin_role and bundle.name == Cog.embedded_bundle do
      {:error, "cannot remove embedded permissions from admin role"}
    else
      JoinTable.dissociate(role, permission)
    end
  end

end

defimpl Poison.Encoder, for: Cog.Models.Role do
  def encode(struct, options) do
    map = struct
    |> Map.from_struct
    |> Map.take([:id, :name])

    Poison.Encoder.Map.encode(map, options)
  end
end
