defmodule Cog.Commands.Trigger.Enable do
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Enable a pipeline trigger. Provided as a convenient alternative to `trigger update <trigger-name> --enabled=true`.

  USAGE
    trigger enable [FLAGS] <name>

  ARGS
    name  Specifies the trigger to enable.

  FLAGS
    -h, --help  Display this usage info

  EXAMPLES

    trigger enable my-trigger
  """

  def enable(%{options: %{"help" => true}}, _args),
    do: show_usage
  def enable(req, [name]) do
    options = %{"enabled" => true}
    req = %{req | options: options}
    case Cog.Commands.Trigger.Update.update(req, [name]) do
      {:ok, _, data} ->
        {:ok, "trigger-enable", data}
      other ->
        other
    end
  end

end
