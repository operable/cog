defmodule Cog.Commands.Pluck do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, calling_convention: :all
  alias Cog.Helpers, as: CogHelpers
  alias Cog.Command.Helpers, as: CommandHelpers

  @moduledoc """
  Returns the specified fields from a set of inputs.

  ## Example

      @bot #{Cog.embedded_bundle}:rules --list --for-command="#{Cog.embedded_bundle}:permissions" | #{Cog.embedded_bundle}:pluck --fields=id
      > { "id": "91edb472-04cf-4bca-ba05-e51b63f26758" }
        { "id": "738ce922-14cd-4abc-fe94-81658707229c" }
      @bot #{Cog.embedded_bundle}:rules --list --for-command="#{Cog.embedded_bundle}:permissions" | #{Cog.embedded_bundle}:pluck --fields=rule,command
      > { "rule": "operable:manage_users",
          "command": "operable:permissions" }
        { "rule": "operable:manage_users",
          "command": "operable:permissions" }

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

  defp validate(req) do
    %__MODULE__{req: req}
    |> validate_inputs
    |> validate_options
  end

  defp validate_options(%__MODULE__{req: %{options: %{"fields" => opt_fields}}, input: item}=state) do
    fields = String.split(opt_fields, ",")
    case Enum.reduce(fields, true, &contains_field(item, &1, &2)) do
      true -> %{state | fields: fields}
      false -> CommandHelpers.add_errors(state, :invalid_field)
    end
  end
  defp validate_options(%__MODULE__{req: %{options: _}}=state),
    do: %{state | fields: []}

  defp contains_field(item, field, acc) do
    result = Map.fetch(item, field)
    |> CogHelpers.is_ok?
    result and acc
  end

  defp validate_inputs(%__MODULE__{req: %{cog_env: item}}=state),
    do: %{state | input: item}

  defp execute(%{errors: [_|_]}=state), do: state
  defp execute(%__MODULE__{fields: [], input: item}=state),
    do: %{state | output: item}
  defp execute(%__MODULE__{fields: fields, input: item}=state) when is_map(item),
    do: %{state | output: Map.take(item, fields)}
  defp execute(%__MODULE__{fields: _, input: item}=state),
    do: %{state | output: item}

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

  defp translate_error(:invalid_field),
    do: "You entered a field that is not present in each instance."
end
