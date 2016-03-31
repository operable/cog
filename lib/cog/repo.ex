defmodule Cog.Repo do
  use Ecto.Repo, otp_app: :cog

  def exists?(model, id) do
    case get(model, id) do
      nil ->
        false
      _ ->
        true
    end
  end

end
