
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
                        "execution_failure" => ""},
                      [%{"name" => "attachment",
                         "title" => "Pipeline Error",
                         "color" => "#ff3333",
                         "children" => [
                           %{"name" => "fixed_width_block", "text" => "bad stuff happened"}
                         ],
                         "fields" => [
                           %{"short" => false, "title" => "Started", "value" => "some time in the past"},
                           %{"short" => false, "title" => "Pipeline ID", "value" => "deadbeef"},
                           %{"short" => false, "title" => "Pipeline", "value" => "echo foo"},
                           %{"short" => false, "title" => "Failed Planning", "value" => "I can't plan this!"},
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
                        "planning_failure" => "",
                        "execution_failure" => "I can't execute this!"},
                      [%{"name" => "attachment",
                         "title" => "Command Execution Error",
                         "color" => "#ff3333",
                         "children" => [
                           %{"name" => "fixed_width_block", "text" => "bad stuff happened"}
                         ],
                         "fields" => [
                           %{"short" => false, "title" => "Started", "value" => "some time in the past"},
                           %{"short" => false, "title" => "Pipeline ID", "value" => "deadbeef"},
                           %{"short" => false, "title" => "Pipeline", "value" => "echo foo"},
                           %{"short" => false, "title" => "Failed Executing", "value" => "I can't execute this!"},
                           %{"short" => false, "title" => "Caller", "value" => "somebody"},
                         ]}])
  end

end
