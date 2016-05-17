defmodule Cog.Models.Permission do
  use Cog.Model
  use Cog.Models
  alias Ecto.Changeset

  schema "permissions_v2" do
    belongs_to :bundle, Bundle
    field :name, :string

    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  summary_fields [:id, :name, :bundle]
  detail_fields [:id, :name, :bundle]

  @doc """
  Allows for the inclusion of the namespace model
  when inserting a new permission.

  Allows the Insert to error out with a changeset, if the insertion
  is not completed successfully
  """
  def build_new(%Bundle{}=bundle, params) do
    bundle
    |> Ecto.Model.build(:permissions)
    |> changeset(params)
  end

  @doc """
  This function is for use when creating a new permission, but outside
  of the API. This can be used during the installation process - whether
  for bootstrapping or installing a new command.

  Assumes a successful insertion into the database or it throws an error.

  Internal operable use only.
  """
  def insert_new(%Bundle{}=bundle, params) do
    bundle
    |> build_new(params)
    |> Repo.insert!
  end

  def changeset(model, params) do
    model
    |> Changeset.cast(params, @required_fields, @optional_fields)
    |> Changeset.unique_constraint(:name, name: "permissions_v2_bundle_id_name_index")
  end

  @doc """
  We often refer to permissions by their full namespaced names,
  particularly in command rules.

  In order to more easily retrieve permissions from the database, we
  need to split this apart and access the namespace and the name
  separately.

  Example:

     iex> Cog.Models.Permission.split_name("s3:delete")
     {"s3", "delete"}

  """
  def split_name(full_name) do
    [bundle, name] = String.split(full_name, ":")
    {bundle, name}
  end

end
