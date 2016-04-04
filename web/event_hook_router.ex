defmodule Cog.EventHookRouter do
  use Cog.Web, :router

  pipeline :hook do
    plug Cog.Plug.Event
    plug :accepts, ["json"]
  end

  scope "/", Cog do
    pipe_through :hook

    post "/v1/event_hooks/:id", V1.EventHookExecutionController, :execute_hook
  end
end
