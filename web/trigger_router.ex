defmodule Cog.TriggerRouter do
  use Cog.Web, :router

  pipeline :trigger do
    plug Cog.Plug.Event
    plug :accepts, ["json"]
  end

  scope "/", Cog do
    pipe_through :trigger

    post "/v1/triggers/:id", V1.TriggerExecutionController, :execute_trigger
  end
end
