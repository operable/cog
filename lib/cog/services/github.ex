defmodule Cog.Services.GitHub do
  use Cog.GenService

  def service_init(_) do
    config = Application.get_env(:cog, :github_service)
    case Keyword.fetch!(config, :api_token) do
      nil ->
        Logger.error("GitHub API token [config entry :cog/:github_service/:api_token] is missing or empty.")
        Logger.error("Aborting GitHub service startup.")
        :ignore
      token ->
        Logger.info("Using API token #{inspect token}")
        client = Tentacat.Client.new(%{access_token: token})
        {:ok, client}
    end
  end

  def handle_message("repo", req, client) do
    repo = String.split(req.parameters["for"], "/")
    results = get_repos(repo, client)
    {:reply, get_response(results), req, client}
  end
  def handle_message("prs", req, client) do
    repo = String.split(req.parameters["for"], "/")
    results = get_prs(repo, req.parameters, client)
    {:reply, get_response(results), req, client}
  end
  def handle_message(_, _, client),
    do: {:noreply, client}

  defp get_response(results) when is_list(results),
    do: results
  defp get_response({code, message}) do
    %{"error" => code,
      "response" => message}
  end

  defp get_repos([org, repo], client),
    do: Tentacat.get("repos/#{org}/#{repo}", client)
  defp get_repos([org], client),
    do: Tentacat.Repositories.list_orgs(org, client)

  defp get_prs([org, repo], %{"closed" => true}, client) do
    case Tentacat.Pulls.filter(org, repo, %{state: "closed"}, client) do
      results when is_list(results) ->
        Enum.take(results, 10)
      error ->
        error
    end
  end
  defp get_prs([org, repo], _, client),
    do: Tentacat.Pulls.filter(org, repo, %{state: "open"}, client)

end
