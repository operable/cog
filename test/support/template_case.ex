defmodule Cog.TemplateCase do
  use ExUnit.CaseTemplate, async: true

  alias Cog.Template.New

  using do
    quote do
      import unquote(__MODULE__)
      @moduletag :template
    end
  end

  def assert_rendered_template(:slack, bundle, template_name, data, expected) when is_binary(expected) do
    directives = directives_for_template(bundle, template_name, data)
    {rendered, _} = Cog.Chat.Slack.TemplateProcessor.render(directives)
    assert expected == rendered
  end
  def assert_rendered_template(:slack, bundle, template_name, data, {text, attachments}) do
    directives = directives_for_template(bundle, template_name, data)
    {message, rendered} = Cog.Chat.Slack.TemplateProcessor.render(directives)
    assert text == message
    cond do
      is_binary(attachments) ->
        assert attachments == Enum.at(rendered, 0) |> Map.get("text")
      length(attachments) == 0 ->
        assert attachments == rendered
      attachments ->
        attachments
        |> Enum.with_index
        |> Enum.each(fn({attachment, index}) -> assert attachment == Enum.at(rendered, index) |> Map.get("text") end)
    end
  end

  def assert_directives({bundle, template_name}, data, expected),
    do: assert expected == directives_for_template(bundle, template_name, data)
  def assert_directives(template_name, data, expected),
    do: assert_directives({:common, template_name}, data, expected)

  def directives_for_template(bundle, template_name, data) do
    source = template_source(template_name, bundle)
    case Cog.Template.New.Evaluator.do_evaluate(template_name, source, data) do
      {:error, reason} ->
        flunk "Greenbar evaluation error: #{reason}"
      directives ->
        directives |> stringify
    end
  end

  # This mimics the round-trip through Carrier that real code will
  # experience.
  defp stringify(input),
    do: input |> Poison.encode! |> Poison.decode!

  def template_source(template_name, bundle) when bundle in [:common, :embedded] do
    New.template_dir(bundle)
    |> Path.join("#{template_name}#{New.extension}")
    |> File.read!
  end
end
