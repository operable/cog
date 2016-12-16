defmodule Cog.Commands.Alias do
  alias Cog.Repo
  alias Cog.Commands.Helpers
  alias Cog.Models.{UserCommandAlias, SiteCommandAlias}

  def error(errors) when is_list(errors),
    do: Enum.map_join(errors, "\n", &error/1)
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
  def error(error),
    do: Helpers.error(error)

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

end
