defmodule Cog.TemplateCase do
  use ExUnit.CaseTemplate, async: true

  alias Cog.Template.New

  using do
    quote do
      import unquote(__MODULE__)
      @moduletag :template
    end
  end

  # TODO: HARD CODED FOR SLACK
  def assert_rendered_template(bundle, template_name, data, expected) do
    directives = directives_for_template(bundle, template_name, data)
    rendered = Cog.Chat.Slack.TemplateProcessor.render(directives)
    assert expected == rendered
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
