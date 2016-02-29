defmodule Cog.Commands.Alias.Helpers do
  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Models.EctoJson

  @moduledoc """
  A collection of helper functions for working with aliases.
  """

  @doc """
  Gets the current user based on the handle and provider.
  """
  def get_user(%{"handle" => handle, "provider" => provider}) do
    Queries.User.for_handle(handle, provider)
    |> Repo.one
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
  def error(errors) when is_list(errors),
    do: Enum.map_join(errors, "\n", &error/1)
  def error({:db_errors, errors}),
    do: db_errors(errors)
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
  def error(:alias_in_user),
    do: "Alias is already in the 'user' namespace."
  def error(:alias_in_site),
    do: "Alias is already in the 'site' namespace."
  def error({:alias_not_found, alias}),
    do: "I can't find '#{alias}'. Please try again"
  def error(:bad_pattern),
    do: "Invalid alias name. Only emoji, letters, numbers, and the following special characters are allowed: *, -, _"
  def error(:too_many_wildcards),
    do: "Too many wildcards. You can only include one wildcard in a query"
  def error(:no_subcommand),
    do: "I don't what to do, please specify a subcommand"
  def error({:unknown_subcommand, subcommand}),
    do: "Unknown subcommand '#{subcommand}'"

  @doc """
  Returns an alias. If the visibility isn't passed we first search for a user
  alias and if that isn't found we search for a site alias.
  """
  def get_command_alias(user, "user:" <> user_alias),
    do: Repo.get_by(UserCommandAlias, name: user_alias, user_id: user.id)
  def get_command_alias(_, "site:" <> site_alias),
    do: Repo.get_by(SiteCommandAlias, name: site_alias)
  def get_command_alias(user, alias) do
    case get_command_alias(user, "user:#{alias}") do
      nil ->
        get_command_alias(user, "site:#{alias}")
      src_alias ->
        src_alias
    end
  end

  @doc """
  We can potentially get poison errors when encoding models with nil fields.
  Here we use EctoJson to convert the model to something poison can work with
  more easily.
  """
  def jsonify(data),
    do: EctoJson.render(data)

  # Special errors that come when there are issues with the database.
  defp db_errors(errors) do
    Enum.map_join(errors, "\n", fn
      ({:name, "has already been taken"}) ->
        "The alias name is already in use."
      ({key, message}) ->
        "#{key} #{message}"
    end)
  end

end
