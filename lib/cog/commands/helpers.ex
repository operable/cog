defmodule Cog.Commands.Helpers do
  alias Cog.Repo
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Models.EctoJson

  @moduledoc """
  A collection of helper functions and macros for working with commands.
  """

  # Adds moduledoc and the show_usage function
  defmacro usage(usage_str) do
    quote do
      @moduledoc unquote(usage_str)

      defp show_usage(error \\ nil) do
        if error do
          {:error, error}
        else
          {:ok, "usage", %{usage: @moduledoc}}
        end
      end
    end
  end

  # In addition to the standard usage bits this also
  # add the 'help' option. Note that this will fail
  # if used outside of a gen_command
  defmacro usage(:root, usage_str) do
    quote do
      Cog.Commands.Helpers.usage(unquote(usage_str))
      option "help", type: "bool", short: "h"
    end
  end

  @doc """
  Returns a tuple containing the subcommand and remaining args
  """
  @spec get_subcommand(List.t) :: {String.t, List.t}
  def get_subcommand([]),
    do: {nil, []}
  def get_subcommand([subcommand | args]),
    do: {subcommand, args}

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
  def error({:relay_not_found, relay_name}),
    do: "No relay with name '#{relay_name}' could be found"
  def error({:relays_not_found, missing_relays}),
    do: "Some relays could not be found: '#{Enum.join(missing_relays, ", ")}'"
  def error({:bundles_not_found, missing_bundles}),
    do: "Some bundles could not be found: '#{Enum.join(missing_bundles, ", ")}'"
  def error({:relay_group_not_found, relay_group_name}),
    do: "No relay group with name '#{relay_group_name}' could be found"
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
  def error({:resource_not_found, "rule", id}),
    do: "Could not find 'rule' with the id '#{id}'"
  def error({:resource_not_found, resource_type, resource_name}),
    do: "Could not find '#{resource_type}' with the name '#{resource_name}'"

  @doc """
  Returns an alias. If the visibility isn't passed we first search for a user
  alias and if that isn't found we search for a site alias.
  """
  def get_command_alias(user_id, "user:" <> user_alias),
    do: Repo.get_by(UserCommandAlias, name: user_alias, user_id: user_id)
  def get_command_alias(_, "site:" <> site_alias),
    do: Repo.get_by(SiteCommandAlias, name: site_alias)
  def get_command_alias(user_id, alias) do
    case get_command_alias(user_id, "user:#{alias}") do
      nil ->
        get_command_alias(user_id, "site:#{alias}")
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
      {key, {message, []}} ->
        "#{key}: #{message}"
      {key, message} ->
        "#{key}: #{message}"
    end)
  end

  defp changeset_errors(changeset) do
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

end
