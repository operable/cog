defmodule Cog.Commands.Trigger.Create do
  alias Cog.Repository.Triggers
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  Create a pipeline trigger.

  USAGE
    trigger create [FLAGS] <name> <pipeline> [OPTIONS]

  ARGS
    name       The human-readable unique name for a trigger
    pipeline   Entire command pipeline text.

  FLAGS
    -h, --help  Display this usage info

  OPTIONS
    -e, --enabled     (Boolean) Should the trigger be created in an enabled
                      state, or not? Defaults to true.
    -d, --description (String) Free text description of the trigger. Defaults to nil.
    -u, --as-user     (String) The Cog username the trigger will execute as. Defaults to nil.
    -t, --timeout-sec (Integer) Amount of time Cog will wait for
                      execution to finish. Defaults to 30. Must be greater than 0

  For more detail on these, consult http://docs.operable.io/docs/triggers

  EXAMPLES

    trigger create my-trigger "echo 'Hello World'" -d "A friendly greeting"

  """

  def create(%{options: %{"help" => true}}, _args),
    do: show_usage
  def create(req, [name, pipeline]),
    do: do_create(name, pipeline, req.options)
  def create(_req, _args),
    do: {:error, :invalid_args}

  defp do_create(name, pipeline, options) do
    params = Cog.Command.Trigger.Helpers.normalize_params(options)
    |> Map.put("pipeline", pipeline)
    |> Map.put("name", name)

    case Triggers.new(params) do
      {:ok, trigger} ->
        {:ok, "trigger-create", trigger}
      {:error, error} ->
        {:error, {:trigger_invalid, error}}
    end
  end
end
