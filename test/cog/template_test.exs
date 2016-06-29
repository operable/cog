defmodule Cog.TemplateTest do
  use ExUnit.Case, async: false
  alias Cog.Template

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Cog.Repo, {:shared, self()})

    :ok
  end

  test "rendering json for the slack adapter" do
    context = %{
      a: %{
        b: [1, 2, 3],
        c: "test"
      }
    }

    {:ok, output} = Template.render("slack", nil, "json", context)

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
