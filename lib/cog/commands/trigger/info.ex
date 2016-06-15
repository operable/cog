defmodule Cog.Commands.Trigger.Info do
  require Cog.Commands.Helpers, as: Helpers
  alias Cog.Repository.Triggers
  require Logger

  Helpers.usage """
  Get detailed information about a trigger.

  USAGE
    trigger info [FLAGS] <name>

  ARGS
    name    The trigger to get info about

  FLAGS
    -h, --help    Display this usage info

  EXAMPLES

    trigger info my-trigger
  """

  def info(%{options: %{"help" => true}}, _args),
    do: show_usage
  def info(_req, [name]) do
    case Triggers.by_name(name) do
      {:ok, trigger} ->
        {:ok, "trigger-info", trigger}
      {:error, :not_found} ->
        {:error, {:resource_not_found, "trigger", name}}
    end
  end
  def info(_, _),
    do: {:error, {:not_enough_args, 1}}

end
