defmodule Cog.TemplateTest do
  use ExUnit.Case
  alias Cog.Template

  test "rendering json for the slack adapter" do
    context = %{
      a: %{
        b: [1, 2, 3],
        c: "test"
      }
    }

    {:ok, output} = Template.render("slack", 1, "json", context)

    assert output == """
    ```
    {
      "a": {
        "c": "test",
        "b": [
          1,
          2,
          3
        ]
      }
    }
    ```
    """
  end
end
