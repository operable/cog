defmodule Cog.Commands.Trigger.List do
  alias Cog.Repository.Triggers

  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all triggers.

  USAGE
    trigger list [FLAGS]

  FLAGS
    -h, --help  Display this usage info
  """

  def list(%{options: %{"help" => true}}, _args),
    do: show_usage

  def list(_req, _args),
    do: {:ok, "trigger-list", Triggers.all}

end
