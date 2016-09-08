defmodule Cog.Chat.Slack.Templates.Common.ErrorTest do
  use Cog.TemplateCase

  test "error template; planning failure" do
    data = %{"id" => "deadbeef",
             "started" => "some time in the past",
             "initiator" => "somebody",
             "pipeline_text" => "echo foo",
             "error_message" => "bad stuff happened",
             "planning_failure" => "I can't plan this!",
             "execution_failure" => false}

    directives = directives_for_template(:common, "error", data)
    rendered = Cog.Chat.Slack.TemplateProcessor.render(directives)

    assert """
    An error has occurred!
    At some time in the past, somebody initiated the following pipeline, assigned the unique ID deadbeef:

    ```
    echo foo
    ```

    The pipeline failed planning the invocation:

    ```
    I can't plan this!
    ```

    The specific error was:

    ```
    bad stuff happened
    ```
    """ |> String.strip == rendered
  end

  test "error template; execution failure" do

    data = %{"id" => "deadbeef",
             "started" => "some time in the past",
             "initiator" => "somebody",
             "pipeline_text" => "echo foo",
             "error_message" => "bad stuff happened",
             "planning_failure" => false,
             "execution_failure" => "I can't execute this!"}
    directives = directives_for_template(:common, "error", data)
    rendered = Cog.Chat.Slack.TemplateProcessor.render(directives)
    assert """
    An error has occurred!
    At some time in the past, somebody initiated the following pipeline, assigned the unique ID deadbeef:

    ```
    echo foo
    ```

    The pipeline failed executing the command:

    ```
    I can't execute this!
    ```

    The specific error was:

    ```
    bad stuff happened
    ```
    """ |> String.strip  == rendered
  end

end
