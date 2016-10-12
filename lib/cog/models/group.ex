defmodule Cog.Models.Group do
  use Cog.Model
  use Cog.Models.EctoJson

  alias Cog.Models.GroupPermission
  alias Cog.Models.GroupRole
  alias Cog.Models.GroupGroupMembership
  alias Cog.Models.UserGroupMembership

  alias Ecto.Changeset

  schema "groups" do
    field :name, :string

    has_many :group_membership, GroupGroupMembership, foreign_key: :group_id
    has_many :direct_group_members, through: [:group_membership, :member]

    has_many :user_membership, UserGroupMembership, foreign_key: :group_id
    has_many :direct_user_members, through: [:user_membership, :member]

    has_many :permission_grants, GroupPermission
    has_many :permissions, through: [:permission_grants, :permission]

    has_many :role_grants, GroupRole
    has_many :roles, through: [:role_grants, :role]
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  summary_fields [:id, :name]
  detail_fields [:id, :name]

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
    |> protect_admin_group
  end

  @doc """
  Creates a changeset based on the `model` and `params`.
  """
  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> protect_admin_group
    |> unique_constraint(:name, name: :groups_name_index)
  end

  defp protect_admin_group(%Changeset{data: data}=changeset) do
    if data.name == Cog.Util.Misc.admin_group do
      changeset
      |> add_error(:name, "admin group may not be modified")
    else
      changeset
    end
  end

end

defimpl Permittable, for: Cog.Models.Group do

  def grant_to(group, permission_or_role),
    do: Cog.Models.JoinTable.associate(group, permission_or_role)

  def revoke_from(%Cog.Models.Group{name: unquote(Cog.Util.Misc.admin_group)=group_name},
                  %Cog.Models.Role{name: unquote(Cog.Util.Misc.admin_role)=role_name}),
    do: {:error, {:permanent_role_grant, role_name, group_name}}
  def revoke_from(group, permission_or_role),
    do: Cog.Models.JoinTable.dissociate(group, permission_or_role)

end

defimpl Groupable, for: Cog.Models.Group do

  def add_to(group_member, group) do
    try do
      Cog.Models.JoinTable.associate(group_member, group)
    rescue
      error in [Postgrex.Error] ->
        # Doing this whole nasty try/rescue deal here because Ecto
        # doesn't have the kind of built-in constraints that we're
        # using (trigger-thrown exceptions). We tried forking Ecto,
        # but it and Postgrex don't make it easy to flexibly add this
        # kind of support
        #
        # Instead of wading into that right now, blocking further
        # progress on our own stuff, I'm just going to brute-force
        # things and handle the exceptions directly.
        #
        # It's a little gross, in that it's here at the site of
        # invocation, rather than bundled up with the changeset like
        # it should be. However, it works, which is rather nice.
        case error do
          # Here, the `message` is what is returned by the
          # `forbid_group_cycles` trigger function in the database. We
          # match on that to ensure we're only getting our specific
          # exception.
          %Postgrex.Error{postgres: %{code: :raise_exception,
                                       message: "group cycles are forbidden"}} ->
            {:error, :forbidden_group_cycle}
        end
    end
  end

  def remove_from(group_member,group),
    do: Cog.Models.JoinTable.dissociate(group_member, group)

end

defimpl Poison.Encoder, for: Cog.Models.Group do
  def encode(struct, options) do
    members = Enum.flat_map(struct.user_membership, fn
      (%{member: member}) -> [member]
      (_) -> []
    end)

    map = struct
    |> Map.from_struct
    |> Map.take([:id, :name, :roles])
    |> Map.put(:members, members)

    Poison.Encoder.Map.encode(map, options)
  end
end
