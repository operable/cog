defmodule Cog.Commands.Pluck do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, calling_convention: :all
  alias Cog.Command.Helpers, as: CommandHelpers

  @moduledoc """
  Returns the specified fields from a set of inputs.
  Be sure to add quotes when traversing a JSON path.

  ## Example

      @bot #{Cog.embedded_bundle}:rules --list --for-command="#{Cog.embedded_bundle}:permissions" | #{Cog.embedded_bundle}:pluck --fields=id
      > { "id": "91edb472-04cf-4bca-ba05-e51b63f26758" }
        { "id": "738ce922-14cd-4abc-fe94-81658707229c" }
      @bot #{Cog.embedded_bundle}:rules --list --for-command="#{Cog.embedded_bundle}:permissions" | #{Cog.embedded_bundle}:pluck --fields=rule,command
      > { "rule": "operable:manage_users",
          "command": "operable:permissions" }
        { "rule": "operable:manage_users",
          "command": "operable:permissions" }
      @bot #{Cog.embedded_bundle}:seed '[{"foo":{"bar.qux":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | #{Cog.embedded_bundle}:pluck --fields=foo"
      > [ {"foo": {"bar.qux": {"baz": "stuff"} } }, {"foo": {"bar": {"baz": "me"} } } ]
      @bot #{Cog.embedded_bundle}:seed '[{"foo":{"bar":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | #{Cog.embedded_bundle}:pluck --fields="foo.bar"
      > { "foo.bar": {"baz": "stuff"} }
        { "foo.bar": {"baz": "me"} }
      @bot #{Cog.embedded_bundle}:seed '[{"foo":{"bar":{"baz":"stuff"}}, "qux": "one"}, {"foo": {"bar":{"baz":"me"}}, "qux": "two"}]' | #{Cog.embedded_bundle}:pluck --fields="qux,\"foo.bar\""
      > { "qux": "one", "foo.bar": {"baz": "stuff"} }
        { "qux": "two", "foo.bar": {"baz": "me"} }
  """

  option "fields", type: "string", required: false

  defstruct req: nil, fields: nil, input: nil, output: nil, errors: []

  def handle_message(req, state) do
    case req |> validate |> execute |> format do
      {:ok, data} ->
        {:reply, req.reply_to, data, state}
      {:error, error} ->
        {:error, req.reply_to, error, state}
    end
  end

  defp validate(%{cog_env: item}=req) do
    %__MODULE__{req: req, input: item}
    |> validate_options
  end

  defp validate_options(%__MODULE__{req: %{options: %{"fields" => opt_fields}}}=state) when not is_binary(opt_fields),
    do: CommandHelpers.add_errors(state, {:not_string, opt_fields})
  defp validate_options(%__MODULE__{req: %{options: %{"fields" => opt_fields}}, input: item}=state) do
    fields = String.split(opt_fields, ",")
    |> Enum.map(&get_nested(&1))
    |> Enum.take_while(fn(field) -> field != [] end)

    case Enum.reject(fields, &get_in(item, &1)) do
      [] ->
        %{state | fields: fields}
      missing ->
        CommandHelpers.add_errors(state, {:invalid_field, missing})
    end
  end
  defp validate_options(%__MODULE__{req: %{options: _}}=state),
    do: %{state | fields: []}

  # This handles any JSON paths that need to be traversed
  defp get_nested(field) do
    cond do
      String.contains?(field, "\"") ->
        Regex.split(~r/\.|\.\"|\"\.|\"/, field)
      String.contains?(field, "'") ->
        Regex.split(~r/\.|\.\'|\'\.|'/, field)
      String.contains?(field, ".") ->
        Regex.split(~r/\./, field)
      true ->
        [field]
    end
    |> Enum.reject(fn(field) -> field == "" end)
  end

  # Catch the errors if there are any first
  defp execute(%__MODULE__{errors: [_|_]}=state), do: state
  # If there are not fields specified, just forward the item
  defp execute(%__MODULE__{fields: [], input: item}=state),
    do: %{state | output: item}
  defp execute(%__MODULE__{fields: fields, input: item}=state) when is_map(item) do
    output = for field <- fields, into: %{}, do: traverse_field(item, field)
    %{state | output: output}
  end
  # If the input is not a map of data to be traversed, just return the input
  defp execute(%__MODULE__{fields: _, input: item}=state),
    do: %{state | output: item}

  defp traverse_field(item, field) do
    key = Enum.join(field, ".")
    {key, get_in(item, field)}
  end

  defp format(%__MODULE__{errors: [_|_]=errors}) do
    error_strings = errors
    |> Enum.map(&translate_error/1)
    |> Enum.map(&("* #{&1}\n"))
    {:error, """

             #{error_strings}
             """}
  end
  defp format(%__MODULE__{output: output}),
    do: {:ok, output}

  defp translate_error({:not_string, fields}),
    do: "You entered a field that is ambiguous. Please quote the following in the field option: #{inspect fields}"
  defp translate_error({:invalid_field, missing}) do
    fields = Enum.map(missing, &Enum.join(&1, "."))
    "You entered a field that is not present in each instance: #{inspect fields}"
  end
end
