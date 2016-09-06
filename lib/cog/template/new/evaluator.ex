defmodule Cog.Template.New.Evaluator do
  alias Cog.Queries
  alias Cog.Repo

  # IDEA: if there's a size limit for a provider, make the provider
  # renderer aware of that and act accordingly.

  @greenbar_errors [Greenbar.CompileError, Greenbar.EvaluationError]

  alias Greenbar.Engine

  require Logger

  def evaluate(name, data),
    do: evaluate(nil, name, data)

  def evaluate(bundle_version_id, name, data) do

    {bundle_version_id, original_template} = case template_name(name, data) do
                                               {:fallback, name} ->
                                                 {nil, name}
                                               ^name ->
                                                 {bundle_version_id, name}
                                             end

    case fetch_source(bundle_version_id, original_template) do
      {:ok, original_source} ->
        try do
          do_evaluate(original_template, original_source, data)
        rescue
          original_error in @greenbar_errors ->
            fallback_template = "error-template-evaluation"
            try do
              {:ok, fallback_source} = fetch_source(nil, fallback_template)
              do_evaluate(fallback_template, fallback_source,
                          %{"error" => inspect(original_error.message),
                            "template" => original_template,
                            "source" => original_source,
                            "data" => data})

            # Let's try and recover from ANYTHING THAT COULD POSSIBLY GO WRONG
            catch
              fallback_error ->
                raw_error_message_directives(original_template, original_error, fallback_template, fallback_error, data)
              :error, fallback_error ->
                raw_error_message_directives(original_template, original_error, fallback_template, fallback_error, data)
            rescue
              fallback_error in @greenbar_errors ->
                Logger.warn(">>>>>>> rescue fallback_error = #{inspect fallback_error, pretty: true}")
                raw_error_message_directives(original_template, original_error, fallback_template, fallback_error, data)
            end
        end
      {:error, :template_not_found} ->
        evaluate(nil, "error-template-not-found", %{"template" => original_template,
                                                    "data" => data})
    end
  end

  ########################################################################

  defp template_name(nil, data) do
    if data_is_text?(data) do
      {:fallback, "text"}
    else
      {:fallback, "raw"}
    end
  end
  defp template_name(name, _data),
    do: name

  # Data is considered text if it's all single-key maps with the key
  # "body"; the value is a list of lines.
  #
  # A little hacky, but this is backward compatible with older Cog
  # templating.
  defp data_is_text?(%{"results" => data}),
    do: Enum.all?(data, &(Map.keys(&1) == ["body"] and is_list(Map.get(&1, "body"))))
  defp data_is_text?(_),
    do: false

  defp fetch_source(bundle_version_id, template) do
    source = Queries.Template.template_source(Cog.Template.New.default_provider, bundle_version_id, template)
    |> Repo.one

    case source do
      nil ->
        {:error, :template_not_found}
      source ->
        {:ok, source}
    end
  end

  # Template evaluation has to bottom out at some point. Rather than
  # writing this message in a template (which has to be evaluated,
  # which could cause an error...), we construct the response
  # directives manually.
  defp raw_error_message_directives(original_template, original_error, fallback_template, fallback_error, data) do
    [text("Irony level exceeded: error evaluating '#{original_template}' and '#{fallback_template}' templates"),
     newline,
     text("The '#{original_template}' template processing failed with the following error:"),
     fixed_width(inspect(original_error)),
     newline,
     text("The '#{fallback_template}' template processing failed with the following error:"),
     fixed_width(inspect(fallback_error)),
     newline,
     text("The result of the pipeline was:"),
     newline,
     json(data)]
  end

  ########################################################################
  # Directive Helpers

  defp text(text),
    do: %{"name" => "text", "text" => text}

  defp newline,
    do: %{"name" => "newline"}

  defp fixed_width(text),
    do: %{"name" => "fixed_width", "text" => text}

  defp json(json),
    do: fixed_width(Poison.encode!(json))

  ########################################################################

  # public for tests _only_
  def do_evaluate(name, source, data) do
    {:ok, engine} = Engine.new
    engine
    |> Engine.compile!(name, source)
    |> Engine.eval!(name, data)
  end

end
