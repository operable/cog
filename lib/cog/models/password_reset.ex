defmodule Cog.Models.PasswordReset do
  use Cog.Model
  alias Cog.Model.User

  schema "password_resets" do
    belongs_to :user, User

    timestamps
  end

  @required_fields ~w(user_id)
  @optional_fields ~w()

  def changeset(model, params) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
