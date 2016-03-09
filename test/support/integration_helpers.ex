defmodule Cog.Integration.Helpers do
  @moduledoc """
  These are generic Cog integration test helper functions that can be used when
  testing Cog commands.
  """

  def render_template(template_name, data) when is_list(data),
    do: Enum.map_join(data, "\n", &(render_template(template_name, &1)))
  def render_template(template_name, data) do
    template = Cog.Repo.get_by(Cog.Models.Template, %{name: template_name, adapter: "test"})
    FuManchu.render!(template.source, data)
  end

  @doc """
  Executes commands in a pipeline

  GIVEN
  - "input": a map or list of json information
  - "pipeline": a string containing the command to be executed on the json data

  RETURNS
  - A map containing the :errors key with a list of errors that were generated
  when validating key aspects of a command's input.

  EXAMPLE
    > seed(%{input: %{1 => "hello"}, errors: []}, {:not_string, [1]})
    %{errors: [not_string: [1]], input: %{1 => "hello"}}

  """
  def seed(input, pipeline) when is_list(input) or is_map(input),
    do: "@bot: seed '#{Poison.encode!(input)}' | #{pipeline}"

  @doc """
  This function recovers an Elixir data structure from this string,
  by relying on the fact that the boundary between maps will be
  "}\n{", which is done with a regex with positive look ahead and
  look behind.

  GIVEN
  - "output_string":

  RETURNS
  - A list of maps

  EXAMPLE
    > unmangle_multiple_output("{\n  \"foo\": 123\n}\n{\n  \"foo\": 321\n}")
    [%{foo: 123}, %{foo: 321}]

  """
  # Currently, it's impossible to get a JSON array of data out of the
  # end of a pipeline. Instead, we get newline-separated JSON strings
  # of each individual data map in that array
  #
  # Now you have `n` problems.
  def unmangle_multiple_output(output_string),
    do: output_string |> String.split(~r/(?<=})\n(?={)/) |> Enum.map(&Poison.decode!(&1, keys: :atoms))
end
