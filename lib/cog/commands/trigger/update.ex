defmodule Cog.Commands.Trigger.Update do
  alias Cog.Repository.Triggers
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Update a pipeline trigger.

  USAGE
    trigger update [FLAGS] <name> [OPTIONS]

  ARGS
    name     The human-readable unique name for a trigger (required)

  FLAGS
    -h, --help  Display this usage info

  OPTIONS

    -d, --description (String) Free text description of the trigger. Defaults to nil.
    -e, --enabled     (Boolean) Whether the trigger will be enabled or not
    -n, --name        (String) the new name of the trigger
    -p, --pipeline    (String) The new text of the pipeline for this trigger
    -t, --timeout-sec (Integer) Amount of time Cog will wait for execution to finish
    -u, --as-user     (String) The Cog username the trigger will execute as.

  For more detail on these, consult http://docs.operable.io/docs/triggers

  EXAMPLES

    trigger update my-trigger -d "A friendly greeting"

  """

  def update(%{options: %{"help" => true}}, _args),
    do: show_usage
  def update(req, [name]),
    do: do_update(name, req.options)
  def update(_req, _args),
    do: {:error, :invalid_args}
  require Logger

  defp do_update(name, options) do
    case Triggers.by_name(name) do
      {:ok, trigger} ->
        params = Cog.Command.Trigger.Helpers.normalize_params(options)
        case Triggers.update(trigger, params) do
          {:ok, trigger} ->
            {:ok, "trigger-update", trigger}
          {:error, error} ->
            {:error, {:trigger_invalid, error}}
        end
      {:error, :not_found} ->
        {:error, {:resource_not_found, "trigger", name}}
    end

  end
end
