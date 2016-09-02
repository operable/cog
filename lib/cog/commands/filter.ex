defmodule Cog.Commands.Filter do
  use Cog.Command.GenCommand.Base, bundle: Cog.Util.Misc.embedded_bundle

  @description "Filter elements of a collection"

  @moduledoc """
  #{@description}

  Filters a collection where the `path` equals the `matches`.
  The `path` option is the key that you would like to focus on;
  The `matches` option is the value that you are searching for.

  USAGE
    filter [OPTIONS]

  OPTIONS
    -m, --matches    The value to search for
    -p, --path       The key to focus on

  EXAMPLES
    rule --list --for-command="permissions" | filter --path="rule" --matches="/manage_users/"
    > { "id": "91edb472-04cf-4bca-ba05-e51b63f26758",
        "rule": "operable:manage_users",
        "command": "operable:permissions" }

    seed '[{"foo":{"bar.qux":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | filter --path="foo.bar.baz""
    > [ {"foo": {"bar.qux": {"baz": "stuff"} } }, {"foo": {"bar": {"baz": "me"} } } ]

    seed '[{"foo":{"bar.qux":{"baz":"stuff"}}}, {"foo": {"bar":{"baz":"me"}}}]' | filter --path="foo.\\"bar.qux\\".baz""
    > { "foo": {"bar.qux": {"baz": "stuff"} } }
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:filter allow"

  option "matches", short: "m", type: "string", required: false
  option "path", short: "p", type: "string", required: false

  defstruct req: nil, expanded_path: nil, match: nil, input: nil, output: nil, errors: []

  def handle_message(req, state) do
    case req |> validate |> execute |> format do
      {:ok, data} ->
        {:reply, req.reply_to, data, state}
      {:error, error} ->
        {:error, req.reply_to, error, state}
    end
  end

  defp validate(req) do
    %__MODULE__{req: req}
    |> validate_options
    |> validate_inputs
  end

  defp validate_options(%__MODULE__{req: %{options: %{"path" => path, "matches" => matches}}}=state) do
    validate_matches(state, matches)
    |> validate_path(path)
  end
  defp validate_options(%__MODULE__{req: %{options: %{"path" => path}}}=state),
    do: validate_path(state, path)
  defp validate_options(%__MODULE__{req: %{options: %{"matches" => _}}}=state),
    do: add_errors(state, :missing_path)
  defp validate_options(%__MODULE__{req: %{options: _}}=state),
    do: state

  defp validate_matches(state, matches) do
    case compile_regex(matches) do
      {:ok, regex} -> %{state | match: regex}
      {:error, _} -> add_errors(state, :bad_match)
    end
  end

  def validate_path(state, path), do: %{state | expanded_path: build_path(path)}

  defp validate_inputs(%__MODULE__{req: %{cog_env: item}}=state),
    do: %{state | input: item}

  defp execute(%{errors: [_|_]}=state), do: state
  defp execute(%__MODULE__{expanded_path: nil, input: item, match: nil}=state),
    do: %{state | output: item}
  defp execute(%__MODULE__{expanded_path: expanded_path, input: item, match: nil}=state) do
    case get_in(item, expanded_path) do
      nil -> state
      _ -> %{state | output: item}
    end
  end
  defp execute(%__MODULE__{expanded_path: expanded_path, input: item, match: match}=state) do
    path = get_in(item, expanded_path)
    case String.match?(to_string(path), match) do
      true -> %{state | output: item}
      false -> state
    end
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

  defp add_errors(input, error_or_errors),
    do: Map.update!(input, :errors, &Enum.concat(&1, List.wrap(error_or_errors)))

  defp translate_error(:missing_path),
    do: "Must specify '--path' with the '--matches' option."
  defp translate_error(:bad_match),
    do: "The regular expression in '--matches' does not compile correctly."

  # Helper functions for the filter command
  defp build_path(path) do
    cond do
      String.contains?(path, "\"") ->
        Regex.split(~r/\.\"|\"\.|\"/, path)
      String.contains?(path, "'") ->
        Regex.split(~r/\.\'|\'\.|'/, path)
      true ->
        Regex.split(~r/\./, path)
    end
    |> Enum.reject(fn(x) -> x == "" end)
  end

  defp compile_regex(string) do
    case Regex.run(~r/^\/(.*)\/(.*)$/, string) do
      nil ->
        Regex.compile(string)
      [_, regex, opts] ->
        Regex.compile(regex, opts)
    end
  end
end
