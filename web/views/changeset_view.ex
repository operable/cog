defmodule Cog.ChangesetView do
  use Cog.Web, :view

  def render("error.json", %{changeset: changeset}) do
    %{errors: changeset}
  end
end
