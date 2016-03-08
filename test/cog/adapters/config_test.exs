defmodule Cog.Adapters.ConfigTest do
  use ExUnit.Case, async: true
  alias Cog.Adapters.Config

  test "simple config" do
    put_config(
      name: "Example",
      description: "My Example Configuration",
      initial_size: "123",
      max_size: 200
    )

    schema = [:name, :description, :initial_size, :max_size]

    {:ok, config} = Config.fetch_config(TestConfig, schema)

    assert config == %{
      name: "Example",
      description: "My Example Configuration",
      initial_size: "123",
      max_size: 200
    }
  end

  test "config mapping" do
    put_config(
      name: "Example",
      description: "My Example Configuration",
      initial_size: "123",
      max_size: 200
    )

    schema = [
      strings: [
        {:name, [:required]},
        :description,
        {:version, :hardcode, "v0.1"}
      ],
      numbers: [
        {:size, [:integer], :initial_size},
        {:max, [:required, :integer], :max_size}
      ]
    ]

    {:ok, config} = Config.fetch_config(TestConfig, schema)

    assert config == %{
      strings: %{
        name: "Example",
        description: "My Example Configuration",
        version: "v0.1"
      },
      numbers: %{
        size: 123,
        max: 200
      }
    }
  end

  test "config with mising keys" do
    put_config([])
    {:error, config} = Config.fetch_config(TestConfig, [{:testy, [:required], :testy}])
    assert config == %{testy: [:missing_required_key]}
  end

  test "config with uncoercable types" do
    put_config(how_many_cheeseburgers: "five")
    {:error, config} = Config.fetch_config(TestConfig, [{:how_many_cheeseburgers, [:integer], :how_many_cheeseburgers}])
    assert config == %{how_many_cheeseburgers: [:unable_to_parse_integer]}
  end

  test "config with correct and incorrect values" do
    put_config(double: "check",
               how_many_cheeseburgers: "five",
               another: "env var")

    {:error, config} = Config.fetch_config(TestConfig,
                                           [{:testy, [:required, :boolean]},
                                             {:double, :hardcode, "triple"},
                                             {:how_many_cheeseburgers, [:integer]},
                                             {:optional, []}])

    assert config == %{testy: [:missing_required_key],
                       how_many_cheeseburgers: [:unable_to_parse_integer]}
  end

  test "module with config" do
    defmodule TestConfig do
      use Cog.Adapters.Config,
        schema: [:testy, :double, :how_many_cheeseburgers]
    end

    put_config([testy: "mctesterson",
                double: "check",
                how_many_cheeseburgers: 5],
               Cog.Adapters.ConfigTest.TestConfig)

    {:ok, config} = TestConfig.fetch_config

    assert config == %{testy: "mctesterson",
                       double: "check",
                       how_many_cheeseburgers: 5}
  end

  defp put_config(config, module \\ TestConfig) do
    Application.put_env(:cog, module, config)
  end
end
