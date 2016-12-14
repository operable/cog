defmodule Cog.Chat.AllTemplatesTest do
  use ExUnit.Case

  @moduletag :template

  test "all embedded templates have Slack tests" do
    {have_tests, no_tests} = tested_untested("slack")
    if no_tests == [] do
      :ok
    else
      flunk """
      The following embedded bundle templates do not have Slack
      rendering tests defined:

      #{Enum.join(no_tests, "\n")}

      Tests were found for the following templates, however:

      #{Enum.join(have_tests, "\n")}

      NOTE: This just tests for the presence of a dedicated test file
      for each template; it does not make any claims to the
      thoroughness of the tests within those files.

      """
    end
  end

  test "all embedded templates have HipChat tests" do
    {have_tests, no_tests} = tested_untested("hipchat")
    if no_tests == [] do
      :ok
    else
      flunk """
      The following embedded bundle templates do not have Slack
      rendering tests defined:

      #{Enum.join(no_tests, "\n")}

      Tests were found for the following templates, however:

      #{Enum.join(have_tests, "\n")}

      NOTE: This just tests for the presence of a dedicated test file
      for each template; it does not make any claims to the
      thoroughness of the tests within those files.

      """
    end
  end


  def tested_untested(provider) do
    Enum.partition(embedded_template_names,
                   &test_file_exists?(provider, &1))
  end

  def test_file_exists?(provider, template_name) do
    File.exists?(template_name_to_test_file(provider, template_name))
  end

  def embedded_template_names do
    Cog.Template.template_dir(:embedded)
    |> Cog.Repository.Templates.templates_from_files
    |> Map.keys
    |> Enum.sort
  end

  def template_name_to_test_file(provider, template_name) do
    Path.join(["test", "cog", "chat",
               String.downcase(provider), "templates", "embedded",
               String.replace(template_name, "-", "_") <> "_test.exs"])

  end
end
