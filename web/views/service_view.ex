defmodule Cog.V1.ServiceView do
  use Cog.Web, :view

  @moduletag :services

  def render("service.json", %{service: service}) do
    %{name: service.name,
      version: service.version,
      meta_url: meta_url(service)}
  end

  def render("index.json", %{services: services}) do
    %{info: %{cog_version: "0.5.0", # TODD: Pull this from code
              cog_services_api_version: "1", # TODO: Ditto
              services: render_many(services, __MODULE__, "service.json")}}
  end

  def render("show.json", %{service: service}) do
    %{service: %{name: service.name,
                 api: service.api}}
  end

  # Generate a URL where specific service metadata can be obtained.
  defp meta_url(service),
    do: Cog.ServiceRouter.Helpers.service_url(Cog.ServiceEndpoint, :show, service.name)

end
