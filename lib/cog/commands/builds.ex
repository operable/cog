defmodule Cog.Commands.Builds do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle

  permission "builds"
  rule "when command is #{Cog.embedded_bundle}:builds must have #{Cog.embedded_bundle}:builds"

  option "state", type: "string", required: true

  @projects_url "https://api.buildkite.com/v1/organizations/operable/projects"

  #This should be in an env var but for now, and for the sake of the demo,
  #I'm just gonna leave it here.
  @authorization_token "eadd45145e1b18b7b60c65cdb4e03bca41d4b058"

  def init(_, proxy),
    do: {:ok, proxy}

  def handle_message(req, proxy) do
    require Logger
    http_config = %{service: "http/get",
      parameters: %{url: @projects_url,
        headers: %{"Authorization": "Bearer #{@authorization_token}"}}}
    response = Spanner.ServiceProxy.call(proxy, http_config)
    projects = Enum.filter(response, filter_by(req.options["state"]))
    {:reply, req.reply_to, "builds", projects, proxy}
  end

  defp filter_by(state) do
    fn(proj) ->
      proj["featured_build"]["state"] == state
    end
  end
end
