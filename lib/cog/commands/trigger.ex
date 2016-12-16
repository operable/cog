defmodule Cog.Commands.Trigger do

  alias Cog.Commands.Helpers

  def error({:trigger_invalid, %Ecto.Changeset{}=changeset}),
    do: Helpers.changeset_errors(changeset)
  def error(error),
    do: Helpers.error(error)

end
