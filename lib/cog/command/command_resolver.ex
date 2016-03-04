defmodule Cog.Command.CommandResolver do

  alias Cog.Repo
  alias Cog.Queries.Command
  alias Cog.Queries.Alias, as: AliasQuery
  alias Piper.Command.SemanticError

  def find_bundle(<<":", _::binary>>=name, user) do
    find_bundle_or_alias(name, user)
  end
  def find_bundle(name, user) when is_binary(name) do
    if String.contains?(name, ":") do
      :identity
    else
      find_bundle_or_alias(name, user)
    end
  end
  def find_bundle(name, _user) do
    SemanticError.new("#{inspect name}", :no_command)
  end

  defp find_bundle_or_alias(name, user) do
    case get_alias_type(name, user) do
      {:ok, alias_type} ->
        {:ok, alias_type}
      nil ->
        case Repo.all(Command.bundle_for(name)) do
          [] ->
            SemanticError.new(name, :no_command)
          [bundle_name] ->
            {:ok, bundle_name}
          bundle_names when is_list(bundle_names) ->
            SemanticError.new(name, {:ambiguous_command, bundle_names})
        end
    end
  end

  # TODO: This is an expensive operation we need to find a more optimal solution
  # especially considering that it can potentially be executed on every invocation
  # in a pipeline.
  defp get_alias_type(name, user) do
    case Repo.all(AliasQuery.user_alias_by_name(user, name)) do
      [] ->
        case Repo.all(AliasQuery.site_alias_by_name(name)) do
          [] ->
            nil
          _site_alias ->
            {:ok, "site"}
        end
      _user_alias ->
        {:ok, "user"}
    end
  end

end
