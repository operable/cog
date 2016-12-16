defmodule Cog.Commands.Helpers do
  alias Cog.Models.EctoJson
  require Cog.Util.Misc

  @moduledoc """
  A collection of helper functions and macros for working with commands.
  """

  @doc """
  If flag exists and is true will return true, otherwise returns false. Flags
  are defined as boolean options. Options that are not.
  """
  @spec flag?(Map.t, String.t) :: true | false
  def flag?(options, option) do
    Map.has_key?(options, option) and Map.get(options, option, false) == true
  end

  @doc """
  Returns a list of args based on the count in the form of {:ok, <arg_list>}.
  If an insufficent number of args are passed an error is returned {:error, <err>}.
  """
  def get_args(args, count) when is_list(args) and is_integer(count),
    do: do_get_args(args, count: count)
  def get_args(args, opts) when is_list(args) and is_list(opts),
    do: do_get_args(args, opts)
  def get_args(_, _),
    do: {:error, :invalid_args}

  defp do_get_args(args, count: count) when length(args) < count,
    do: {:error, {:not_enough_args, count}}
  defp do_get_args(args, min: min) when length(args) < min,
    do: {:error, {:under_min_args, min}}
  defp do_get_args(args, count: count) when length(args) > count,
    do: {:error, {:too_many_args, count}}
  defp do_get_args(args, max: max) when length(args) > max,
    do: {:error, {:over_max_args, max}}
  defp do_get_args(args, min: min, max: max) when length(args) > max or length(args) < min,
    do: {:error, {:invalid_args, min, max}}
  defp do_get_args(args, _),
    do: {:ok, args}

  @doc """
  A collection of messages for various errors.
  """
  def error(%Ecto.Changeset{}=changeset),
    do: changeset_errors(changeset)
  def error(errors) when is_list(errors),
    do: Enum.map_join(errors, "\n", &error/1)
  def error({:db_errors, errors}),
    do: db_errors(errors)
  def error({:no_user, handle, provider}),
    do: "No user '#{handle}' found for '#{provider}'."
  def error({:not_enough_args, count}),
    do: "Not enough args. Arguments required: exactly #{count}."
  def error({:under_min_args, min}),
    do: "Not enough args. Arguments required: minimum of #{min}."
  def error({:too_many_args, count}),
    do: "Too many args. Arguments required: exactly #{count}."
  def error({:over_max_args, max}),
    do: "Too many args. Arguments required: maximum of #{max}."
  def error({:invalid_args, min, max}),
    do: "Invalid args. Please pass between #{min} and #{max} arguments."
  def error(:invalid_args),
    do: "Invalid argument list"
  def error({:resource_not_found, "rule", id}),
    do: "Could not find 'rule' with the id '#{id}'"
  def error({:resource_not_found, resource_type, resource_name}),
    do: "Could not find '#{resource_type}' with the name '#{resource_name}'"

  @doc """
  We can potentially get poison errors when encoding models with nil fields.
  Here we use EctoJson to convert the model to something poison can work with
  more easily.
  """
  def jsonify(data),
    do: EctoJson.render(data)

  def changeset_errors(changeset) do
    msg_map = Ecto.Changeset.traverse_errors(changeset,
                                             fn
                                               {msg, opts} ->
                                                 Enum.reduce(opts, msg, fn {key, value}, acc ->
                                                   String.replace(acc, "%{#{key}}", to_string(value))
                                                 end)
                                               msg ->
                                                 msg
                                             end)

    msg_map
    |> Enum.map(fn({field, msg}) -> "#{field} #{msg}" end)
    |> Enum.join("\n")
  end

  # Special errors that come when there are issues with the database.
  defp db_errors(errors) do
    Enum.map_join(errors, "\n", fn
      {key, {message, []}} ->
        "#{key}: #{message}"
      {key, message} ->
        "#{key}: #{message}"
    end)
  end

end
