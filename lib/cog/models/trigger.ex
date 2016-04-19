defmodule Cog.Models.Trigger do
  use Cog.Model

  schema "triggers" do
    field :name, :string

    field :pipeline, :string
    field :as_user, :string, default: nil
    field :timeout_sec, :integer, default: 30

    field :enabled, :boolean, default: true
    field :description, :string, default: nil

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
  end

end
