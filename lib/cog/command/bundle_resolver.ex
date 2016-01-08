defmodule Cog.Command.BundleResolver do

  alias Cog.Repo
  alias Cog.Queries.Command
  alias Piper.Command.SemanticError

  def find_bundle(name) when is_binary(name) do
    if String.contains?(name, ":") do
      :identity
    else
      case Repo.all(Command.bundle_for(name)) do
        [bundle] ->
          {:ok, bundle};
        [] ->
          SemanticError.new(name, :no_command)
        bundles ->
          SemanticError.new(name, {:ambiguous_command, bundles})
      end
    end
  end
  def find_bundle(name) do
    SemanticError.new("#{inspect name}", :no_command)
  end

end
