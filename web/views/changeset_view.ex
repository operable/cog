defmodule Cog.ChangesetView do
  use Cog.Web, :view

  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def render("error.json", %{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  def translate_error({message, opts}),
    do: String.replace(message, "%{count}", to_string(opts[:count]))
  def translate_error(message),
    do: message
end
