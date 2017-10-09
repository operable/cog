defmodule Cog.Models.PipelineHistory do
  use Ecto.Schema

  import Ecto.Changeset

  alias Cog.Models.User
  alias Cog.Models.Types.ProcessId

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type Ecto.UUID

  schema "pipeline_history" do
    field :idx, :integer, read_after_writes: true
    field :pid, ProcessId
    field :text, :string
    field :room_name, :string
    field :room_id, :string
    field :provider, :string
    field :count, :integer
    field :state, :string
    field :started_at, :integer
    field :finished_at, :integer

    belongs_to :user, User

    timestamps()
  end

  @required_fields ~w(id text room_name room_id provider count state user_id started_at)
  @optional_fields ~w(pid finished_at)

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> assoc_constraint(:user)
    |> ensure_sane_state
  end

  def elapsed(%__MODULE__{started_at: started_at, finished_at: nil}) do
    DateTime.to_unix(DateTime.utc_now(), :milliseconds) - started_at
  end
  def elapsed(%__MODULE__{started_at: started_at, finished_at: finished_at}) do
    finished_at - started_at
  end

  defp ensure_sane_state(changeset) do
    case get_change(changeset, :state) do
      "finished" ->
        put_change(changeset, :pid, nil)
      _ ->
        changeset
    end
  end

end
