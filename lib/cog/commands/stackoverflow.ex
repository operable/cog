defmodule Cog.Commands.Stackoverflow do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle

  permission "stackoverflow"
  rule "when command is #{Cog.embedded_bundle}:stackoverflow must have #{Cog.embedded_bundle}:stackoverflow"

  @search_url "https://api.stackexchange.com/2.2/search/advanced"
  @search_options %{
    "site": "stackoverflow",
    "order": "asc",
    "sort": "relevance",
    "pagesize": 3
  }

  def init(_, proxy),
    do: {:ok, proxy}

  def handle_message(req, proxy) do
    require Logger
    Logger.warn("#{inspect __MODULE__}: callback state => #{inspect proxy}")

    http_config = %{service: "http/get", parameters: %{url: build_url(req.args), headers: %{"Accept-Encoding": "gzip"}}}
    response = Spanner.ServiceProxy.call(proxy, http_config)
    {:reply, req.reply_to, "stackoverflow", response["items"], proxy}
  end

  defp build_url(args),
    do: "#{@search_url}?#{build_query(args)}"

  defp build_query(args) do
    Map.put(@search_options, "q", Enum.join(args, "+"))
    |> URI.encode_query
  end
end
