defmodule Cog.Commands.Alias.Ls do
  alias Cog.Repo
  alias Cog.Queries
  alias Cog.Commands.Helpers

  @moduledoc """
  Lists aliases. Subcommand for alias.
  Optionally takes a pattern supporting basic wildcards.

  usage:
  alias ls [pattern]

  example:
  alias ls
  alias ls "my-*"
  """

  @doc """
  Entry point for listing aliases.
  Accepts a cog request and argument list.
  Returns {:ok, <alias list>} on success and {:error, <err>} on failure.
  """
  def list_command_aliases(req, arg_list) do
    %{"handle" => handle, "provider" => provider} = req.requestor
    case Helpers.get_args(arg_list, max: 1) do
      {:ok, [pattern]} ->
        case do_list_command_aliases(handle, provider, pattern) do
          {:ok, response} ->
            {:ok, "alias-ls", Enum.sort(response)}
          error ->
            error
        end
      {:ok, []} ->
        case do_list_command_aliases(handle, provider) do
          {:ok, response} ->
            {:ok, "alias-ls", Enum.sort(response)}
          error ->
            error
        end
      error ->
        error
    end
  end

  defp do_list_command_aliases(handle, provider) do
    user_results = Queries.Alias.user_aliases(handle, provider)
    |> Repo.all
    site_results = Queries.Alias.site_aliases()
    |> Repo.all

    {:ok, Helpers.jsonify(user_results ++ site_results)}
  end

  defp do_list_command_aliases(handle, provider, "user:" <> pattern) do
    case sanitary?(pattern) do
      true ->
        results = replace_wildcard(pattern)
        |> Queries.Alias.user_matching(handle, provider)
        |> Repo.all

        {:ok, Helpers.jsonify(results)}
      {false, error} ->
        {:error, error}
    end
  end
  defp do_list_command_aliases(handle, provider, "user") do
    results = Queries.Alias.user_aliases(handle, provider)
    |> Repo.all

    {:ok, Helpers.jsonify(results)}
  end
  defp do_list_command_aliases(_, _, "site:" <> pattern) do
    case sanitary?(pattern) do
      true ->
        results = replace_wildcard(pattern)
        |> Queries.Alias.site_matching()
        |> Repo.all

        {:ok, Helpers.jsonify(results)}
      {false, error} ->
        {:error, error}
    end
  end
  defp do_list_command_aliases(_, _, "site") do
    results = Queries.Alias.site_aliases()
    |> Repo.all

    {:ok, Helpers.jsonify(results)}
  end
  defp do_list_command_aliases(handle, provider, pattern) do
    case sanitary?(pattern) do
      true ->
        user_results = replace_wildcard(pattern)
        |> Queries.Alias.user_matching(handle, provider)
        |> Repo.all
        site_results = replace_wildcard(pattern)
        |> Queries.Alias.site_matching()
        |> Repo.all

        {:ok, Helpers.jsonify(user_results ++ site_results)}
      {false, error} ->
        {:error, error}
    end
  end

  # sanitary/1 verifies that the pattern being passed is valid. It does so by
  # running the pattern through a series of validator functions. Currently we
  # support patterns with the following characters: a-z, A-Z, 0-9, *, -, _.
  # Returns :ok on success {:error, <err>} on failure.
  defp sanitary?(pattern) do
    checkers = [&valid_characters/1,
                &one_wildcard/1]

    results = Enum.reduce(checkers, [], fn(checker, acc) ->
      case checker.(pattern) do
        :ok ->
          acc
        {:error, err} ->
          [err | acc]
      end
    end)

    case results do
      [] ->
        true
      errors ->
        {false, errors}
    end
  end

  # Check that only valid characters have been passed.
  defp valid_characters(pattern) do
    case Regex.match?(~r/^:?[a-zA-Z0-9-_*]+:?$/, pattern) do
      true ->
        :ok
      false ->
        {:error, :bad_pattern}
    end
  end

  # Check that we only have one wildcard.
  defp one_wildcard(pattern) do
    case length(Regex.scan(~r/\*/, pattern)) > 1 do
      true ->
        {:error, :too_many_wildcards}
      false ->
        :ok
    end
  end

  # Replaces the user wildcard(*) with the sql wildcard(%).
  defp replace_wildcard(pattern) do
    Regex.replace(~r/\*/, pattern, "%")
  end
end
