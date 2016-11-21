defmodule Cog.V1.TriggerView do
  use Cog.Web, :view

  def render("trigger.json", %{trigger: trigger}) do
    %{id: trigger.id,
      name: trigger.name,
      description: trigger.description,
      enabled: trigger.enabled,
      pipeline: trigger.pipeline,
      as_user: trigger.as_user,
      timeout_sec: trigger.timeout_sec,
      invocation_url: invocation_url(trigger)}
  end

  def render("index.json", %{triggers: triggers}),
    do: %{triggers: render_many(triggers, __MODULE__, "trigger.json")}

  def render("show.json", %{trigger: trigger}),
    do: %{trigger: render_one(trigger, __MODULE__, "trigger.json")}

  # Generate a URL where the trigger can be invoked. This is on its own
  # distinct Endpoint with a different port than the normal API. We
  # may need to use information from the `conn` to generate this if
  # installed behind a proxy that handles routing between the two
  # endpoints.
  defp invocation_url(trigger) do
    Cog.TriggerRouter.Helpers.trigger_execution_url(Cog.TriggerEndpoint, :execute_trigger, trigger.id)
  end

end
