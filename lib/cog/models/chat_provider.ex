defmodule Cog.Models.ChatProvider do
  use Cog.Model

  @primary_key {:id, :id, autogenerate: true}

  schema "chat_providers" do
    field :name, :string
    field :data, :map
    timestamps
  end

  @required_fields ~w(name)
  @optional_fields ~w(data)

  summary_fields [:id, :name]
  detail_fields [:id, :name]

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
P
end
