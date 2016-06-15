defmodule Cog.Commands.Trigger.Delete do
  alias Cog.Repository.Triggers
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Delete triggers by name.

  USAGE
    trigger delete [FLAGS] <name...>

  ARGS
    name  Specifies the trigger to delete. Multiple names can be supplied.

  FLAGS
    -h, --help  Display this usage info

  EXAMPLES

    trigger:delete foo bar baz

  """

  def delete(%{options: %{"help" => true}}, _args),
    do: show_usage
  def delete(_req, []),
    do: {:error, {:under_min_args, 1}}
  def delete(_req, names) do
    {_count, deleted_triggers} = Triggers.delete(names)
    {:ok, "trigger-delete", deleted_triggers}
  end
end
