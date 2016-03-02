defmodule Cog.Command.CommandResolver do
  alias Cog.Repo
  alias Cog.Models.Command
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Queries

  @doc """
  Resolver function for use in `Piper.Command.ParserOptions.resolver`.
  """
  def command_resolver_fn(user) do
    fn(ns, name) ->
      case lookup(ns, name, user) do
        %Command{}=c ->
          {:command, {c.bundle.name, c.name, c}}
        %UserCommandAlias{pipeline: pipeline} ->
          {:pipeline, pipeline}
        %SiteCommandAlias{pipeline: pipeline} ->
          {:pipeline, pipeline}
        :not_found ->
          :not_found
        {:ambiguous, names} ->
          {:ambiguous, names}
      end
    end
  end

  @spec lookup(String.t | nil, String.t, %Cog.Models.User{}) ::
               %UserCommandAlias{} |
               %SiteCommandAlias{} |
               %Command{} |
               :not_found |
               {:ambiguous, [String.t]}
  def lookup(nil, name, user) do
    case lookup("user", name, user) do
      %UserCommandAlias{}=user_alias ->
        user_alias
      :not_found ->
        case lookup("site", name, user) do
          %SiteCommandAlias{}=site_alias ->
            site_alias
          :not_found ->
            lookup(name)
        end
    end
  end
  def lookup("user", user_alias_name, user),
    do: find_one(Queries.Alias.user_alias_by_name(user, user_alias_name))
  def lookup("site", site_alias_name, _user),
    do: find_one(Queries.Alias.site_alias_by_name(site_alias_name))
  def lookup(bundle, command_name, _user),
    do: find_one(Queries.Command.complete_command(bundle, command_name))

  defp find_one(query) do
    case Repo.one(query) do
      nil -> :not_found
      result -> result
    end
  end

  defp lookup(bare_command_name) do
    case Repo.all(Queries.Command.by_any_name(bare_command_name))do
      [] ->
        :not_found
      [command] ->
        # TODO: find a way to consolidate this with the query above
        Repo.preload(command, [:bundle, :rules, options: :option_type])
      commands ->
        names = commands |> Enum.map(&(&1.bundle.name)) |> Enum.sort
        {:ambiguous, names}
    end
  end

end
