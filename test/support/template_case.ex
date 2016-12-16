defmodule Cog.TemplateCase do
  use ExUnit.CaseTemplate, async: true

  alias Cog.Template
  alias Greenbar.Renderers.SlackRenderer
  alias Greenbar.Renderers.HipChatRenderer

  using do
    quote do
      # Extract the processor name from the module. We can then set the @moduletag
      # to 'template: <processor>' so we can more easily target processor specific
      # template tests.
      processor =
        Module.split(__MODULE__)
        |> Enum.map(&String.downcase/1)
        |> Enum.reduce_while(nil, fn
                               ("hipchat", nil) -> {:halt, :hipchat}
                               ("slack", nil) -> {:halt, :slack}
                               (_, nil) -> {:cont, nil}
        end)

      import unquote(__MODULE__)
      @moduletag templates: processor
    end
  end

  def assert_rendered_template(:hipchat, bundle, template_name, data, expected) when is_binary(expected) do
    directives = directives_for_template(bundle, template_name, data)
    rendered = HipChatRenderer.render(directives)
    assert expected == rendered
  end

  def assert_rendered_template(:slack, bundle, template_name, data, expected) when is_binary(expected) do
    directives = directives_for_template(bundle, template_name, data)
    {rendered, _} = SlackRenderer.render(directives)
    assert expected == rendered
  end
  def assert_rendered_template(:slack, bundle, template_name, data, {text, attachments}) do
    directives = directives_for_template(bundle, template_name, data)
    {message, rendered} = SlackRenderer.render(directives)
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
    case Cog.Template.Evaluator.do_evaluate(template_name, source, data) do
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
    Template.template_dir(bundle)
    |> Path.join("#{template_name}#{Template.extension}")
    |> File.read!
  end

end
