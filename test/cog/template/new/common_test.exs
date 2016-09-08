defmodule Cog.Template.New.CommonTest do
  use Cog.TemplateCase

  test "raw template directives" do
    assert_directives("raw",
                      %{"results" => [%{"foo" => "bar"}]},
                      [%{"name" => "fixed_width",
                         "text" => "[\n  {\n    \"foo\": \"bar\"\n  }\n]"}])
  end

  test "error template directives; planning failure" do
    assert_directives("error",
                      %{"id" => "deadbeef",
                        "started" => "some time in the past",
                        "initiator" => "somebody",
                        "pipeline_text" => "echo foo",
                        "error_message" => "bad stuff happened",
                        "planning_failure" => "I can't plan this!",
                        "execution_failure" => false},
                      [%{"name" => "text", "text" => "An error has occurred!"},
                       %{"name" => "newline"},
                       %{"name" => "text", "text" => "At some time in the past, somebody initiated the following pipeline, assigned the unique ID deadbeef:"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "fixed_width", "text" => "\necho foo\n"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "text", "text" => "The pipeline failed planning the invocation:"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "fixed_width", "text" => "\nI can't plan this!\n"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "text", "text" => "The specific error was:"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "fixed_width", "text" => "\nbad stuff happened\n"}])
  end

  test "error template directives; execution failure" do
    assert_directives("error",
                      %{"id" => "deadbeef",
                        "started" => "some time in the past",
                        "initiator" => "somebody",
                        "pipeline_text" => "echo foo",
                        "error_message" => "bad stuff happened",
                        "planning_failure" => false,
                        "execution_failure" => "I can't execute this!"},
                      [%{"name" => "text", "text" => "An error has occurred!"},
                       %{"name" => "newline"},
                       %{"name" => "text", "text" => "At some time in the past, somebody initiated the following pipeline, assigned the unique ID deadbeef:"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "fixed_width", "text" => "\necho foo\n"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "text", "text" => "The pipeline failed executing the command:"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "fixed_width", "text" => "\nI can't execute this!\n"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "text", "text" => "The specific error was:"},
                       %{"name" => "newline"},
                       %{"name" => "newline"},
                       %{"name" => "fixed_width", "text" => "\nbad stuff happened\n"}])
    end

end
