defmodule Cog.Commands.Trigger.Disable do
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Disable a pipeline trigger. Provided as a convenient alternative to `trigger update <trigger-name> --enabled=false`.

  USAGE
    trigger disable [FLAGS] <name>

  ARGS
    name  Specifies the trigger to disable.

  FLAGS
    -h, --help  Display this usage info

  EXAMPLES

    trigger disable my-trigger
  """

  def disable(%{options: %{"help" => true}}, _args),
    do: show_usage
  def disable(req, [name]) do
    options = %{"enabled" => false}
    req = %{req | options: options}
    case Cog.Commands.Trigger.Update.update(req, [name]) do
      {:ok, _, data} ->
        {:ok, "trigger-disable", data}
      other ->
        other
    end
  end

end
