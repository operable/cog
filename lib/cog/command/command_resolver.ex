defmodule Cog.Command.CommandResolver do

  alias Cog.Repo
  alias Cog.Queries.Command
  alias Cog.Queries.Alias
  alias Piper.Command.SemanticError

  def find_bundle(name) when is_binary(name) do
    if String.contains?(name, ":") do
      :identity
    else
      case Repo.all(Command.bundle_for(name)) do
        [bundle_name] ->
          case get_alias_type(name) do
            {:ok, alias_type} ->
              SemanticError.new(name, {:ambiguous_alias, {bundle_name <> ":" <> name, alias_type <> ":" <> name}})
            nil ->
              {:ok, bundle_name}
          end
        [] ->
          case get_alias_type(name) do
            {:ok, alias_type} ->
              {:ok, alias_type}
            nil ->
              SemanticError.new(name, :no_command)
          end
        bundle_names ->
          SemanticError.new(name, {:ambiguous_command, bundle_names})
      end
    end
  end
  def find_bundle(name) do
    SemanticError.new("#{inspect name}", :no_command)
  end

  defp get_alias_type(name) do
    case Repo.all(Alias.user_alias_by_name(name)) do
      [] ->
        case Repo.all(Alias.site_alias_by_name(name)) do
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
