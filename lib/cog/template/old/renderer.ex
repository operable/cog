defmodule Cog.Template.Old.Renderer do

  @moduledoc """
  Encapsulates old Mustache-based template rendering flow, suitable
  for bundles of version 3 or lower. Later bundles use a new custom
  template renderer, which also changes the semantics of the rendering
  process itself. Once version 3 bundles are no longer supported, this
  module will be removed.

  As much logic as possible has been extracted here, but some
  additional code may remain in Cog.Command.Pipeline.Executor.
  """

  require Logger
  alias Cog.Command.Pipeline.ParserMeta
  alias Cog.Template

  @type adapter_name :: String.t

  # Return a map of adapter -> rendered message
  @spec render_for_adapters([adapter_name], %ParserMeta{}, List.t) ::
  %{adapter_name => String.t} |
  {:error, {term, term, term}} # {error, template, adapter}
  def render_for_adapters(adapters, parser_meta, output) do
    Enum.reduce_while(adapters, %{}, fn(adapter, acc) ->
      case render_templates(adapter, parser_meta, output) do
        {:error, _}=error ->
          {:halt, error}
        message ->
          {:cont, Map.put(acc, adapter, message)}
      end
    end)
  end

  # For a specific adapter, render each output, concatenating all
  # results into a single response string
  defp render_templates(adapter, parser_meta, output) do
    rendered_templates = Enum.reduce_while(output, [], fn({context, template}, acc) ->
      case render_template(adapter, parser_meta, template, context) do
        {:ok, result} ->
          {:cont, [result|acc]}
        {:error, error} ->
          {:halt, {:error, {error, template, adapter}}}
      end
    end)

    case rendered_templates do
      {:error, error} ->
        {:error, error}
      messages ->
        messages
        |> Enum.reverse
        |> Enum.join("\n")
    end
  end

  defp render_template(adapter, parser_meta, template, context) do
    case Template.render(adapter, parser_meta.bundle_version_id, template, context) do
      {:ok, output} ->
        {:ok, output}
      {:error, :template_not_found} ->
        Logger.warn("The template `#{template}` was not found for adapter `#{adapter}` in bundle `#{parser_meta.bundle_name} #{parser_meta.version}`; falling back to the json template")
        Template.render(adapter, "json", context)
      {:error, error} ->
        {:error, error}
    end
  end


end
