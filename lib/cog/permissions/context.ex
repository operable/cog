defmodule Cog.Permissions.Context do

  defstruct permissions: nil, command: nil, options: nil, args: nil, input_matches: %{}

  def new(opts \\ []) do
    permissions = Keyword.get(opts, :permissions)
    command     = Keyword.get(opts, :command)
    options     = Keyword.get(opts, :options)
    args        = Keyword.get(opts, :args)

    %__MODULE__{permissions: permissions, command: command, options: options, args: args}
  end

  def count_matches(%__MODULE__{}=context) do
    Enum.sum(Dict.values(context.input_matches))
  end

  def reset_matches(context),
    do: %{context | input_matches: %{}}

  def add_match(%__MODULE__{}=context, :arg, index) do
    key = "arg#{index}"
    matches = Dict.update(context.input_matches, key, 1, &(&1))
    %{context | input_matches: matches}
  end
  def add_match(%__MODULE__{}=context, :option, name) do
    matches = Dict.update(context.input_matches, name, 1, &(&1))
    %{context | input_matches: matches}
  end
  def add_match(context, _, _),
    do: context

end
