defmodule Cog.Template do
  alias Cog.Queries
  alias Cog.Repo
  alias Cog.TemplateCache

  def render(adapter, bundle_id, template, context) do
    with {:ok, template_fun} <- fetch_compiled_fun(adapter, bundle_id, template, context) do
      template_fun.(context)
    end
  end

  def fetch_compiled_fun(adapter, bundle_id, template, context) do
    with :error              <- TemplateCache.lookup(adapter, bundle_id, template),
         {:ok, source}       <- fetch_source(adapter, bundle_id, template, context),
         {:ok, template_fun} <- compile(source),
         :ok                 <- TemplateCache.insert(adapter, bundle_id, template, template_fun),
         do: {:ok, template_fun}
  end

  def fetch_source(adapter, bundle_id, nil, context) do
    fetch_source(adapter, bundle_id, default_template(context), context)
  end

  # Always use the raw template when responding to the test adapter.
  # Used in integration tests.
  def fetch_source("test", _bundle_id, _template, context) do
    fetch_source("any", nil, "raw", context)
  end

  def fetch_source(adapter, bundle_id, template, _context) do
    with {:error, :template_not_found} <- fetch(adapter, bundle_id, template),
         {:error, :template_not_found} <- fetch(adapter, nil, template),
         {:error, :template_not_found} <- fetch("raw", nil, template),
         do: {:error, :template_not_found}
  end

  def compile(source) do
    case FuManchu.Compiler.compile(source) do
      {:ok, template_fun} ->
        {:ok, wrap_template_fun(template_fun)}
      error ->
        error
    end
  end

  defp fetch(adapter, bundle_id, template) do
    source = Queries.Template.template_source(adapter, bundle_id, template)
    |> Repo.one

    case source do
      nil ->
        {:error, :template_not_found}
      source ->
        {:ok, source}
    end
  end

  defp wrap_template_fun(fun) do
    fn context ->
      try do
        output = fun.(%{context: context, partials: partials})
        {:ok, output}
      rescue
        error ->
          {:error, error}
      end
    end
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
