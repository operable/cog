defmodule Cog.V1.EventHookView do
  use Cog.Web, :view

  def render("hook.json", %{event_hook: hook}) do
    %{id: hook.id,
      name: hook.name,
      description: hook.description,
      active: hook.active,
      pipeline: hook.pipeline,
      as_user: hook.as_user,
      timeout_sec: hook.timeout_sec,
      invocation_url: invocation_url(hook)}
  end

  def render("index.json", %{event_hooks: hooks}),
    do: %{event_hooks: render_many(hooks, __MODULE__, "hook.json")}

  def render("show.json", %{event_hook: hook}),
    do: %{event_hook: render_one(hook, __MODULE__, "hook.json")}

  # Generate a URL where the hook can be invoked. This is on its own
  # distinct Endpoint with a different port than the normal API. We
  # may need to use information from the `conn` to generate this if
  # installed behind a proxy that handles routing between the two
  # endpoints.
  defp invocation_url(hook),
    do: Cog.EventHookRouter.Helpers.event_hook_execution_url(Cog.EventHookEndpoint, :execute_hook, hook.id)


end
