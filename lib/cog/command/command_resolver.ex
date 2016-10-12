defmodule Cog.Command.CommandResolver do

  alias Cog.Command.Pipeline.ParserMeta
  alias Cog.Models.SiteCommandAlias
  alias Cog.Models.UserCommandAlias
  alias Cog.Queries
  alias Cog.Repo
  alias Cog.Repository.Bundles
  alias Cog.Repository.Rules

  @doc """
  Resolver function for use in `Piper.Command.ParserOptions.resolver`.
  """
  def command_resolver_fn(user) do
    enabled_bundles = Cog.Repository.Bundles.enabled_bundles

    fn(bundle_name, name) ->
      case lookup(bundle_name, name, user, enabled_bundles) do
        %ParserMeta{}=parser_meta ->
          {:command, {parser_meta.bundle_name, parser_meta.command_name, parser_meta}}
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

  def lookup(nil, name, user, enabled_bundles) do
    case lookup("user", name, user, enabled_bundles) do
      %UserCommandAlias{}=user_alias ->
        user_alias
      :not_found ->
        case lookup("site", name, user, enabled_bundles) do
          %SiteCommandAlias{}=site_alias ->
            site_alias
          :not_found ->
            lookup(name, enabled_bundles)
        end
    end
  end
  def lookup("user", user_alias_name, user, _),
    do: find_one(Queries.Alias.user_alias_by_name(user, user_alias_name))
  def lookup("site", site_alias_name, _user, _),
    do: find_one(Queries.Alias.site_alias_by_name(site_alias_name))
  def lookup(bundle_name, command_name, _user, enabled_bundles) do
    case Map.get(enabled_bundles, bundle_name) do
      nil ->
        # No enabled version of the requested bundle was found
        :not_found
      version ->
        case Bundles.command_for_bundle_version(command_name, bundle_name, version) do
          nil ->
            # The enabled bundle version does not contain the
            # requested command
            :not_found
          result ->
            {:ok, rules} = Rules.rules_for_command(result.command)
            Cog.Command.Pipeline.ParserMeta.new(result.command.bundle.name,
                                                result.command.name,
                                                result.bundle_version,
                                                result.options,
                                                rules)
        end
    end
  end

  defp lookup(bare_command_name, enabled_bundles) do
    case Bundles.bundle_names_for_command(bare_command_name) do
      [] ->
        :not_found
      [bundle_name] ->
        lookup(bundle_name, bare_command_name, :not_used, enabled_bundles)
      bundle_names ->
        {:ambiguous, Enum.sort(bundle_names)}
    end
  end

  defp find_one(query) do
    case Repo.one(query) do
      nil -> :not_found
      result -> result
    end
  end

end
