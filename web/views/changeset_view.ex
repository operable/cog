defmodule Cog.ChangesetView do
  use Cog.Web, :view

  def render("error.json", %{changeset: changeset}) do
    errors = Enum.reduce(changeset.errors, %{}, fn {key, value}, acc ->
      Map.merge(acc, %{key => [value]}, fn _key, value1, value2 ->
        value1 ++ value2
      end)
    end)

    %{errors: errors}
  end
end
