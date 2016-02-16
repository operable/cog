defmodule Cog.Repo.Migrations.AddListCommandOptionType do
  use Ecto.Migration

  alias Cog.Models.CommandOptionType
  alias Cog.Repo

  def change do
    %CommandOptionType{}
    |> CommandOptionType.changeset(%{name: "list"})
    |> Repo.insert!
  end
end
