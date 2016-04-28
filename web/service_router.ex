defmodule Cog.ServiceRouter do
  use Cog.Web, :router

  pipeline :service do
    plug Cog.Plug.Event
    plug :accepts, ["json"]
  end

  scope "/", Cog do
    pipe_through :service

    get "/v1/services/meta", V1.ServiceController, :index
    get "/v1/services/meta/deployed/:name", V1.ServiceController, :show

    get "/v1/services/memory/1.0.0/:key", V1.MemoryServiceController, :show
    delete "/v1/services/memory/1.0.0/:key", V1.MemoryServiceController, :delete
    put "/v1/services/memory/1.0.0/:key", V1.MemoryServiceController, :update
    post "/v1/services/memory/1.0.0/:key", V1.MemoryServiceController, :change

  end
end
