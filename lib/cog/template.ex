defmodule Cog.Template do
  alias Cog.Queries
  alias Cog.Repo

  def render(adapter, bundle_id, template, context) do
    try do
      with {:ok, source} <- fetch_source(adapter, bundle_id, template, context),
           {:ok, function} <- compile(source),
           output = function.(%{context: context, partials: partials}),
           do: {:ok, output}
    rescue
      error ->
        {:error, error}
    end
  end

  def fetch_source(adapter, bundle_id, nil, context) do
    fetch_source(adapter, bundle_id, default_template(context), context)
  end

  # That extra newline is there for a reason. Mustache spec strips newlines
  # following a standalone partial. No idea why.
  def fetch_source("slack", _bundle_id, "json", _context) do
    source = """
    ```
    {{> json}}

    ```
    """

    {:ok, source}
  end

  def fetch_source("hipchat", _bundle_id, "json", _context) do
    source = """
    /code
    {{> json}}
    """

    {:ok, source}
  end

  def fetch_source(_adapter, _bundle_id, template, _contenxt) when template in ["raw", "json"] do
    source = """
    {{> json}}
    """

    {:ok, source}
  end

  def fetch_source(_adapter, _bundle_id, "text", _contenxt) do
    source = """
    {{> text}}
    """

    {:ok, source}
  end

  def fetch_source("any", bundle_id, template, _context) do
    case fetch("any", bundle_id, template) do
      nil ->
        {:error, :template_not_found}
      source ->
        {:ok, source}
    end
  end

  def fetch_source(adapter, bundle_id, template, context) do
    case fetch(adapter, bundle_id, template) do
      nil ->
        fetch_source("any", bundle_id, template, context)
      source ->
        {:ok, source}
    end
  end

  def compile(source) do
    FuManchu.Compiler.compile(source)
  end

  defp fetch(adapter, bundle_id, template) do
    Queries.Template.template_source(adapter, bundle_id, template)
    |> Repo.one
  end

  defp partials do
    %{json: &render_json/1,
      text: &render_text/1}
  end

  def render_json(context),
    do: Poison.encode!(context, pretty: true)

  def render_text(%{"body" => body}) when is_list(body),
    do: Enum.join(body, "\n")
  def render_text(%{"body" => body}) when is_binary(body),
    do: body
  def render_text(text) when is_binary(text),
    do: text

  defp default_template(%{"body" => _}),                  do: "text"
  defp default_template(context) when is_binary(context), do: "text"
  defp default_template(context) when is_map(context),    do: "json"
  defp default_template(_),                               do: "raw"
end
