defmodule Cog.Permissions.Context do

  defstruct user: nil, permissions: nil, command: nil, options: nil, args: nil, input_matches: %{}

  def new(opts \\ []) do
    user = Keyword.get(opts, :user)
    permissions = case Keyword.get(opts, :permissions) do
                    nil ->
                      case user != nil do
                        true ->
                          Cog.Models.User.all_permissions(user)
                        false ->
                          []
                      end
                    v ->
                      v
                  end
    command = Keyword.get(opts, :command)
    options = Keyword.get(opts, :options)
    args = Keyword.get(opts, :args)

    %__MODULE__{user: user, permissions: permissions, command: command, options: options, args: args}
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
