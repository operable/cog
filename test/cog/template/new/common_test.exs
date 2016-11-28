
defmodule Cog.Template.New.CommonTest do
  use Cog.TemplateCase

  test "raw template directives" do
    assert_directives("raw",
                      %{"results" => [%{"foo" => "bar"}]},
                      [%{"name" => "fixed_width_block",
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
                      [%{"name" => "attachment",
                         "title" => "Pipeline Error",
                         "color" => "#ff3333",
                         "children" => [
                           %{"name" => "text", "text" => "The pipeline failed planning the invocation:"},
                           %{"name" => "newline"},
                           %{"name" => "fixed_width_block", "text" => "I can't plan this!"}
                         ],
                         "fields" => []},
                       %{"name" => "attachment",
                         "title" => "Error Message",
                         "color" => "#ff3333",
                         "children" => [
                           %{"name" => "fixed_width_block", "text" => "bad stuff happened"}
                         ],
                         "fields" => []},
                       %{"name" => "attachment",
                         "color" => "#ff3333",
                         "children" => [],
                         "fields" => [
                           %{"short" => false, "title" => "Started", "value" => "some time in the past"},
                           %{"short" => false, "title" => "Pipeline ID", "value" => "deadbeef"},
                           %{"short" => false, "title" => "Pipeline", "value" => "echo foo"},
                           %{"short" => false, "title" => "Caller", "value" => "somebody"}
                         ]}])
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
                      [%{"name" => "attachment",
                         "title" => "Command Error",
                         "color" => "#ff3333",
                         "children" => [
                           %{"name" => "text", "text" => "The pipeline failed executing the command:"},
                           %{"name" => "newline"},
                           %{"name" => "fixed_width_block", "text" => "I can't execute this!"}
                         ],
                         "fields" => []},
                       %{"name" => "attachment",
                         "title" => "Error Message",
                         "color" => "#ff3333",
                         "children" => [
                           %{"name" => "fixed_width_block", "text" => "bad stuff happened"}
                         ],
                         "fields" => []},
                       %{"name" => "attachment",
                         "color" => "#ff3333",
                         "children" => [],
                         "fields" => [
                           %{"short" => false, "title" => "Started", "value" => "some time in the past"},
                           %{"short" => false, "title" => "Pipeline ID", "value" => "deadbeef"},
                           %{"short" => false, "title" => "Pipeline", "value" => "echo foo"},
                           %{"short" => false, "title" => "Caller", "value" => "somebody"}
                         ]}])
  end

end
