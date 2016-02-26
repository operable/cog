defmodule Cog.Command.AliasExpander do
  alias Cog.Repo
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Command.CommandResolver
  alias Piper.Command.Parser
  alias Piper.Command.Ast

  @moduledoc """
  Expands aliases into pipelines
  """

  @doc """
  expand takes a fully qualified alias name and returns the pipeline cooresponding
  to the associated command string or an error if an alias cannot be found.
  """
  def expand(alias_name) do
    limit = Application.get_env(:cog, :max_alias_expansion, 5)
    case is_alias?(alias_name) do
      true ->
        expand(alias_name, [], limit, 0)
      false ->
        {:ok, :not_an_alias}
    end
  end

  defp expand(alias_name, acc, limit, current_depth) when current_depth <= limit do
    case get_alias(alias_name) do
      :not_found ->
        {:error, "Command alias not found"}
      command_alias ->
        case Parser.scan_and_parse(command_alias.pipeline, command_resolver: &CommandResolver.find_bundle/1, return_pipeline: true) do
          {:ok, %Ast.Pipeline{invocations: invocations}} ->
            [invocation|rest] = invocations
            case is_alias?(invocation.command) do
              true ->
                expand(invocation.command, rest ++ acc, limit, current_depth + 1)
              false ->
                {:ok, invocations ++ acc}
            end
          error ->
            error
        end
    end
  end
  defp expand(alias_name, _acc, limit, _current_depth) do
    {:error, "Error expanding alias '#{alias_name}'. Expansion goes beyond the configured limit of '#{limit}'."}
  end

  defp get_alias("user:" <> name) do
    case Repo.get_by(UserCommandAlias, name: name) do
      nil ->
        :not_found
      user_alias ->
        user_alias
    end
  end
  defp get_alias("site:" <> name) do
    case Repo.get_by(SiteCommandAlias, name: name) do
      nil ->
        :not_found
      site_alias ->
        site_alias
    end
  end

  defp is_alias?("site:" <> _),
    do: true
  defp is_alias?("user:" <> _),
    do: true
  defp is_alias?(_),
    do: false
end
