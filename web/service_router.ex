defmodule Cog.ServiceRouter do
  use Cog.Web, :router

  pipeline :service do
    plug Cog.Plug.Event
    plug :accepts, ["json"]
  end

  scope "/v1/services", Cog do
    pipe_through :service

    get "/meta", V1.ServiceController, :index
    get "/meta/deployed/:name", V1.ServiceController, :show

    get "/memory/1.0.0/:key", V1.MemoryServiceController, :show
    delete "/memory/1.0.0/:key", V1.MemoryServiceController, :delete
    put "/memory/1.0.0/:key", V1.MemoryServiceController, :update
    post "/memory/1.0.0/:key", V1.MemoryServiceController, :change

  end
end
