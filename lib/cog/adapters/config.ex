defmodule Cog.Adapters.Config do
  require Logger

  @moduledoc """
  The Config module is used to ingest adapter configuration that is specified
  in Mix and apply validations and type coercion. To use it, create new module
  `use Cog.Adapters.Config` with a keyword list containing a `key` key for the
  module under which your config lives and a `schema` key with your schema
  defined. This module assumes that your config is stored under the `:cog` Mix
  configuration with a key of the new module's name.

  The `schema` value should be a list of field specifications which are used to
  extract values from Mix configuration and transform them into adapter
  configuration. Can optionally be configured as a keyword list at the top
  level to logically group related sets of configuration keys.

  ## Schema:

  ### Field Specifications:

    * `key` - The name of the field to map from the Mix configuration. Will be used as the key in the
       returned hash.
    * `{key, [rules], source_field \\ key}`
      * `key` - The name of the key in the returned configuration.
      * `rules` - A list of validation and type coercion rules to apply to the Mix configuration
        values. See below for details.
      * `source_field` - (Optional) The name of the configuration key from the Mix file if it differs
        from the name key to be returned.
    * `{key, :hardcode, value}` - Sets the value of `key` to `value` in the returned configuration
      hash.

  ### Rules:

    * `:required` - A value must be set for this key.
    * `:integer` - Attempt to convert the value to an integer.
    * `:boolean` - Attempt to convert the value to a boolean.
    * `:split` - Splits a String value at comma boundaries and returns a list of the results.

  ### Examples:

  #### Source Mix Configuration:

      config :cog, Example.Config,
        name: "Example",
        description: "My Example Configuraton",
        initial_size: "123",
        max_size: 200

  #### Simple Example:

      defmodule My.Adapter.SimpleConfig do
        use Cog.Adapters.Config,
          key: Example.Config,
          schema: [:name, :description, :inital_size, :max_size]
      end
      
      iex(1)> My.Adapter.SimpleConfig.fetch_config!
      %{name: "Example", description: "My Example Configuration",
        initial_size: 123, max_size: 200}
      
  #### Complex Mapping:

      defmodule My.Adapter.ComplexConfig do
        use Cog.Adapters.Config,
          key: Example.Config,
          schema: [:strings, [{:name, [:required]},
                              :description
                              {:version, :hardcode, "v0.1"}],
                   :numbers, [{:size, [:integer], :initial_size},
                              {:max, [:required, :integer], :max_size}]]
      end
      
      iex(1)> My.Adapter.ComplexConfig.fetch_config!
      %{strings: %{name: "Example", decription: "My Example Configuration"
                   version: "v0.1"},
        numbers: %{size: 123, max: 200}}
  """

  defmacro __using__(options) do
    key = Keyword.get(options, :key, __CALLER__.module)
    schema = Keyword.fetch!(options, :schema)

    quote location: :keep do
      import Cog.Adapters.Config
      require Logger

      def fetch_config do
        Cog.Adapters.Config.fetch_config(unquote(key), unquote(schema))
      end

      def fetch_config! do
        Cog.Adapters.Config.fetch_config!(unquote(key), unquote(schema))
      end
    end
  end

  # TODO: Alter the schema structure to deterministically identify namespaces
  # from two tuple value definitions.
  def fetch_config(key, schema) do
    config = Application.get_env(:cog, key)

    case Keyword.keyword?(schema) do
      true ->
        namespace_config(schema, config)
      false ->
        apply_schema(schema, config)
    end
  end

  def fetch_config!(key, schema) do
    case fetch_config(key, schema) do
      {:ok, config} ->
        config
      {:error, errors} ->
        Enum.each(format_errors(errors), &Logger.error/1)
        raise "Invalid config found for #{inspect(key)}"
    end
  end

  # The schema is namespaced by keys to seperate out the config values.
  # Traverse one level down and run that schema on the top-level config.
  #
  # TODO: Support any level of namespacing by adding some fancy recursion.
  defp namespace_config(schema, config) do
    Enum.reduce(schema, {:ok, %{}}, fn {namespace, schema}, {state, acc} ->
      case apply_schema(schema, config) do
        {^state, value} ->
          {state, Map.put(acc, namespace, value)}
        {:error, value} ->
          {:error, Map.put(%{}, namespace, value)}
        _ ->
          {state, acc}
      end
    end)
  end

  # Iterate through the schema, find matching keys from the config, and run the
  # set of rules in the order defined against the value output from the
  # previous rule.
  defp apply_schema(schema, config) do
    Enum.reduce(schema, {:ok, %{}}, fn field, {state, acc} ->
      case fetch_field(config, field) do
        {^state, {key, value}} ->
          {state, Map.put(acc, key, value)}
        {:error, {key, errors}} ->
          {:error, Map.put(%{}, key, errors)}
        _ ->
          {state, acc}
      end
    end)
  end

  defp fetch_field(config, field) when is_atom(field) do
    fetch_field(config, {field, [], field})
  end

  defp fetch_field(config, {field, rules}) do
    fetch_field(config, {field, rules, field})
  end

  defp fetch_field(_config, {field, :hardcode, value}) do
    {:ok, {field, value}}
  end

  defp fetch_field(config, {field, rules, key}) do
    value = Keyword.get(config, key)

    case apply_rules(rules, value) do
      {:ok, value, []} ->
        {:ok, {field, value}}
      {:error, _value, errors} ->
        {:error, {field, errors}}
    end
  end

  # Run each rule against the modified value at each step. If all rules pass
  # return the new value in an `:ok` tuple. If any rules fail, return an
  # `:error` tuple with the original value and the errors.
  defp apply_rules(rules, value) do
    Enum.reduce(rules, {:ok, value, []}, fn rule, {state, value, acc} ->
      case {state, apply_rule(rule, value)} do
        {:ok, {:ok, value}} ->
          {:ok, value, acc}
        {_, {:error, error}} ->
          {:error, value, [error|acc]}
        {:error, {:ok, value}} ->
          {:error, value, acc}
      end
    end)
  end

  defp apply_rule(:required, value) do
    case value do
      value when not(is_nil(value)) ->
        {:ok, value}
      _ ->
        {:error, :missing_required_key}
    end
  end

  defp apply_rule(:integer, nil),
    do: {:ok, nil}
  defp apply_rule(:integer, value) do
    case value |> to_string |> Integer.parse do
      {integer, ""} ->
        {:ok, integer}
      _ ->
        {:error, :unable_to_parse_integer}
    end
  end

  defp apply_rule(:boolean, nil),
    do: {:ok, nil}
  defp apply_rule(:boolean, value) do
    case value |> to_string do
      "true" ->
        {:ok, true}
      "false" ->
        {:ok, false}
      _ ->
        {:error, :unable_to_parse_boolean}
    end
  end

  defp apply_rule(:split, nil),
    do: {:ok, nil}
  defp apply_rule(:split, value) do
    case value do
      value when is_binary(value) ->
        {:ok, String.split(value, ",")}
      _ ->
        {:error, :unable_to_split_nonbinary}
    end
  end

  # If we try to apply a rule to a missing key, continue successfully with the
  # current value of `:error`.
  defp apply_rule(_, :error) do
    {:ok, :error}
  end

  defp apply_rule(rule, _) do
    raise "Unknown rule #{inspect(rule)} could not be applied"
  end

  defp format_errors(errors) do
    Enum.flat_map(errors, fn
      {_key, map} when is_map(map) ->
        format_errors(map)
      {key, list} when is_list(list) ->
        Enum.map(list, &format_error(&1, key))
    end)
  end

  defp format_error(:missing_required_key, key),
    do: "Required key #{inspect key} was not provided"
  defp format_error(:unable_to_parse_integer, key),
    do: "Unable to parse value for key #{inspect key} as an integer"
  defp format_error(:unable_to_parse_boolean, key),
    do: "Unable to parse value for key #{inspect key} as a boolean"
  defp format_error(:unable_to_split_nonbinary, key),
    do: "Unable to split non-string value for key #{key}"
end
