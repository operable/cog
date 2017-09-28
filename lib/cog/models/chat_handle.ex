defmodule Cog.Models.ChatHandle do
  use Cog.Model
  use Cog.Models.EctoJson

  alias Cog.Models.ChatProvider
  alias Cog.Models.User

  schema "chat_handles" do
    field :handle, :string
    field :chat_provider_user_id, :string
    belongs_to :user, User
    belongs_to :chat_provider, ChatProvider, foreign_key: :provider_id, type: :integer

    timestamps()
  end

  @required_fields ~w(handle user_id provider_id chat_provider_user_id)
  @optional_fields ~w()

  summary_fields [:id, :handle, :user_id, :provider_id, :chat_provider_user_id]
  detail_fields [:id, :handle, :user, :chat_provider, :chat_provider_user_id]

  def changeset(model, params \\ :empty) do
    params = coerce_chat_provider_user_id(params)

    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:handle,
                         name: :chat_handles_provider_id_handle_index,
                         message: "Another user has claimed this chat handle")
  end

  # Normally we would use an `update_change` call for something like this. But,
  # in this case, the value can't be coerced as part of the `cast` call and a
  # changeset is never created. So, instead, we need to mutate the params map
  # before we pass it in to create a changeset.
  defp coerce_chat_provider_user_id(%{"chat_provider_user_id" => chat_provider_user_id} = params),
    do: Map.put(params, "chat_provider_user_id", to_string(chat_provider_user_id))
  defp coerce_chat_provider_user_id(%{chat_provider_user_id: chat_provider_user_id} = params),
    do: Map.put(params, :chat_provider_user_id, to_string(chat_provider_user_id))
  defp coerce_chat_provider_user_id(params),
    do: params
end
