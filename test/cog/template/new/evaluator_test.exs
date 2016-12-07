defmodule Cog.Template.New.EvaluatorTest do
  use ExUnit.Case

  @moduletag templates: :evaluator

  alias Cog.Template.New.Evaluator

  setup do
    # We manually checkout the DB connection each time.
    # This allows us to run tests async.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    :ok
  end

  describe "custom common templates" do

    setup :with_fake_data

    test "error template evaluates normally when there is no custom template dir", %{data: data} do
      expected_directives =
        [%{name: :attachment,
           title: "Pipeline Error",
           color: "#ff3333",
           children: [
             %{name: :fixed_width_block, text: "this is an error"}
           ],
           fields: [
             %{short: false, title: "Started", value: "2016-11-18T20:52:23Z"},
             %{short: false, title: "Pipeline ID", value: "fake_id"},
             %{short: false, title: "Pipeline", value: "fake pipeline"},
             %{short: false, title: "Caller", value: "fake_user"}
           ]}]

      results = Evaluator.evaluate("error", data)
      assert(^expected_directives = results)
    end

    test "error template is replaced when a custom template is available", %{data: data} do
      # Save the original value for the custom_template_dir so we can replace it later
      orig_dir = Application.get_env(:cog, :custom_template_dir)
      on_exit(fn ->
        Application.put_env(:cog, :custom_template_dir, orig_dir)
      end)

      # Update the config value
      Application.put_env(:cog, :custom_template_dir, "fake/dir/path")

      # We'll just mock File.read so we don't have to mess with the file system
      :meck.new(File, [:passthrough])
      :meck.expect(File, :read, fn
                     ("fake/dir/path/error.greenbar") ->
                       :meck.unload(File)
                       {:ok, "fake template body"}
      end)

      # Finally we can call the evaluator
      results = Evaluator.evaluate("error", data)

      # Make sure the evaluator called File
      assert([%{children: [%{name: :text, text: "fake template body"}],
              name: :paragraph}] = results)
    end

  end

  #### Setup Functions ####

  defp with_fake_data(_) do
    [data: %{"id" => "fake_id",
             "started" => "2016-11-18T20:52:23Z",
             "initiator" => "fake_user",
             "pipeline_text" => "fake pipeline",
             "error_message" => "this is an error",
             "execution_failure" => "",
             "planning_failure" => ""}]

  end
end
