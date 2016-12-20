defmodule Cog.Models.Trigger do
  use Cog.Model

  schema "triggers" do
    field :name, :string

    field :pipeline, :string
    field :timeout_sec, :integer, default: 30

    field :enabled, :boolean, default: true
    field :description, :string, default: nil

    # This references the username, rather than the user's UUID, for
    # historical reasons; both are equally unique, and so it functions
    # just as well.
    belongs_to :user, Cog.Models.User,  foreign_key: :as_user, references: :username, type: :string

    timestamps
  end

  @required_fields ~w(name pipeline)
  @optional_fields ~w(as_user timeout_sec enabled description)

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> validate_format(:name, ~r/\A[A-Za-z0-9\_\-\.]+\z/)
    |> validate_number(:timeout_sec, greater_than: 0)
    |> unique_constraint(:name, name: :triggers_name_index)
    |> foreign_key_constraint(:as_user, name: :triggers_as_user_fkey)
  end

end
