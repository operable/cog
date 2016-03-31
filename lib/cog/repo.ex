defmodule Cog.Repo do
  use Ecto.Repo, otp_app: :cog

  alias Cog.Queries.Repo, as: Queries

  def exists?(model, id) do
    case one!(Queries.count_by_id(model, id)) do
      1 -> true
      _ -> false
    end
  end

end
