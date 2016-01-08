defmodule Cog.Models.ChatProvider do
  use Cog.Model

  @primary_key {:id, :id, autogenerate: true}

  schema "chat_providers" do
    field :name, :string

    timestamps
  end

  summary_fields [:id, :name]
  detail_fields [:id, :name]
end
