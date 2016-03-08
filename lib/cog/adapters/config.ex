defmodule Cog.Adapters.Config do
  @moduledoc """
  The Config module is used to ingest adapter configuration that is specified in Mix, apply validations
  and type coercion, cache it in the state of a GenServer, and make it available to the adapter. To use
  it, create new module with `@config` and `@schema` attributes defined, and `use Cog.Adapters.Config`.

    * `@config`: The name of the key to use from the `:cog` Mix configuration.
    * `@schema`: A list of field specifications which are used to extract values from Mix configuration
      and transform them into adapter configuration. Can optionally be configured as a keyword list at the
      top level to logically group related sets of configuration keys.

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
        @config Example.Config
        @schema [ :name, :description, :initial_size, :max_size ]
        
        use Cog.Adapters.Config
      end
      
      iex(1)> My.Adapter.SimpleConfig.fetch_config
      %{name: "Example", description: "My Example Configuration",
        initial_size: 123, max_size: 200}
      
  #### Complex Mapping:

      defmodule My.Adapter.ComplexConfig do
        @config Example.Config
        @schema [:strings, [{:name, [:required]},
                            :description
                            {:version, :hardcode, "v0.1"}],
                 :numbers, [{:size, [:integer], :initial_size},
                            {:max, [:required, :integer], :max_size}]]
        
        use Cog.Adapters.Config
      end
      
      iex(1)> My.Adapter.ComplexConfig.fetch_config
      %{strings: %{name: "Example", decription: "My Example Configuration"
                   version: "v0.1"},
        numbers: %{size: 123, max: 200}}

  """

  defmacro __using__(_) do
    quote do
      use GenServer
      import Supervisor.Spec

      @doc """
      Reads configuration from Mix, applies validations and type coercion, and
      returns a configuration hash. See Cog.Adapters.Config for more information.
      """
      def fetch_config() do
        ensure_running
        GenServer.call(__MODULE__, :get_config)
      end

      def fetch_config(group) do
        Access.get(fetch_config, group)
      end

      def start_link() do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init(_) do
        {:ok, walk_config}
      end

      def handle_call(:get_config, _from, state) do
        {:reply, state, state}
      end

      def walk_config(), do: walk_config(@schema)
      def walk_config(schema) do
        case Keyword.keyword?(schema) do
          true ->
            for key <- Keyword.keys(schema), into: %{},
              do: {key, process_entries(Keyword.get(schema, key))}
          false ->
            process_entries(schema)
        end
      end

      defp process_entries(entries) do
        for entry <- entries, into: %{}, do: process_entry(entry)
      end

      # Field with no options and no source mapping.
      defp process_entry(field) when is_atom(field) do
        process_entry({field, [], field})
      end

      # Hardcoded field.
      defp process_entry({field, :hardcode, value}) do
        {field, value}
      end

      # Field with options, no source mapping.
      defp process_entry({field, options}) do
        process_entry({field, options, field})
      end

      # Field with options and explicit source.
      defp process_entry({field, [], source}) do
        {field, Access.get(mix_config, source)}
      end
      defp process_entry({field, options, source}=field_spec) do
        value = Enum.reduce(options, mix_config[source],
                  fn(opt, acc) -> process_option(opt, acc, field_spec) end)
        {field, value}
      end

      defp process_option(:integer, value, _field_spec) when is_integer(value), do: value
      defp process_option(:integer, value, {_, _, source}) when is_binary(value) do
        try do
          String.to_integer(value)
        rescue
          ArgumentError ->
            raise ArgumentError,
              "The value for configuration key #{source} in #{@config}} must be an integer."
        end
      end
      defp process_option(:boolean, true, _field_spec),
        do: true
      defp process_option(:boolean, "true", _field_spec),
        do: true
      defp process_option(:boolean, false, _field_spec),
        do: false
      defp process_option(:boolean, "false", _field_spec),
        do: false
      defp process_option(:boolean, _value, {_, _, source}),
        do: raise ArgumentError, "The value for configuration key #{source} in #{@config}} must be a boolean."
      defp process_option(:required, value, field_spec) do
        case value do
          nil ->
            {_, _, source} = field_spec
            raise ArgumentError,
              "Required configuration key #{source} not found in configuration for #{@config}"
          value ->
            value
        end
      end

      defp process_option(:split, value, {_, _, source}) when not is_binary(value) do
        raise ArgumentError,
          "Configuration key #{source} in configuration for #{@config} is not a string."
      end
      defp process_option(:split, value, _field_spec) do
        String.split(value, ",")
      end

      defp process_option(option, _value, {field, _, _}) do
        raise ArgumentError, "Invalid constraint (#{option}) defined for configuration key #{field}."
      end

      defp mix_config do
        Application.get_env(:cog, @config)
      end

      defp ensure_running do
        case Process.whereis(__MODULE__) do
          nil ->
            Supervisor.start_link([worker(__MODULE__, [])],
                                  name: Module.concat(__MODULE__, "Supervisor"),
                                  strategy: :one_for_one)
          pid ->
            pid
        end
      end
    end
  end
end
