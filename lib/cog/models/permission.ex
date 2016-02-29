defmodule Cog.Models.Permission.Namespace do
  use Cog.Model
  alias Ecto.Changeset

  schema "namespaces" do
    field :name, :string
    belongs_to :bundle, Cog.Models.Bundle
    has_many :permissions, Cog.Models.Permission
  end

  @required_fields ~w(name)
  @optional_fields ~w(bundle_id)

  summary_fields [:id, :name]
  detail_fields [:id, :name]

  def changeset(model, params) do
    model
    |> Changeset.cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:name)
  end
end

defmodule Cog.Models.Permission do
  use Cog.Model
  alias Ecto.Changeset
  alias Cog.Models.Permission.Namespace

  schema "permissions" do
    belongs_to :namespace, Namespace
    field :name, :string
  end

  @required_fields ~w(name)
  @optional_fields ~w()

  summary_fields [:id, :name, :namespace]
  detail_fields [:id, :name, :namespace]

  @doc """
  Allows for the inclusion of the namespace model
  when inserting a new permission. 

  Allows the Insert to error out with a changeset, if the insertion
  is not completed successfully
  """
  def build_new(%Namespace{}=namespace, params) do
    namespace
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
  def insert_new(%Namespace{}=namespace, params) do
    namespace
    |> build_new(params)
    |> Repo.insert!
  end

  def changeset(model, params) do
    model
    |> Changeset.cast(params, @required_fields, @optional_fields)
    |> Changeset.unique_constraint(:name, name: "permissions_namespace_id_name_index")
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
    [ns, name] = String.split(full_name, ":")
    {ns, name}
  end

end
