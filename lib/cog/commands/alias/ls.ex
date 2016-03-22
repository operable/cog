defmodule Cog.Commands.Alias.Ls do
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Queries
  alias Cog.Repo

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
    %{"id" => user_id, "provider" => provider} = req.requestor

    user = Queries.User.for_chat_provider_user_id(user_id, provider)
    |> Repo.one!

    case Helpers.get_args(arg_list, max: 1) do
      {:ok, [pattern]} ->
        case do_list_command_aliases(user, pattern) do
          {:ok, response} ->
            {:ok, "alias-ls", Enum.sort(response)}
          error ->
            error
        end
      {:ok, []} ->
        case do_list_command_aliases(user) do
          {:ok, response} ->
            {:ok, "alias-ls", Enum.sort(response)}
          error ->
            error
        end
      error ->
        error
    end
  end

  defp do_list_command_aliases(user) do
    user_aliases = Repo.all(Queries.Alias.for_user(user.id))
    site_aliases = Repo.all(SiteCommandAlias)
    aliases = user_aliases ++ site_aliases

    {:ok, Helpers.jsonify(aliases)}
  end

  defp do_list_command_aliases(user, "user:" <> pattern) do
    case sanitary?(pattern) do
      true ->
        pattern = replace_wildcard(pattern)

        aliases = UserCommandAlias
        |> Queries.Alias.for_user(user.id)
        |> Queries.Alias.matching(pattern)
        |> Repo.all

        {:ok, Helpers.jsonify(aliases)}
      {false, error} ->
        {:error, error}
    end
  end
  defp do_list_command_aliases(user, "user") do
    aliases = Repo.all(Queries.Alias.for_user(user.id))

    {:ok, Helpers.jsonify(aliases)}
  end
  defp do_list_command_aliases(_user, "site:" <> pattern) do
    case sanitary?(pattern) do
      true ->
        pattern = replace_wildcard(pattern)

        aliases = SiteCommandAlias
        |> Queries.Alias.matching(pattern)
        |> Repo.all

        {:ok, Helpers.jsonify(aliases)}
      {false, error} ->
        {:error, error}
    end
  end
  defp do_list_command_aliases(_user, "site") do
    aliases = Repo.all(SiteCommandAlias)

    {:ok, Helpers.jsonify(aliases)}
  end
  defp do_list_command_aliases(user, pattern) do
    case sanitary?(pattern) do
      true ->
        pattern = replace_wildcard(pattern)

        user_aliases = UserCommandAlias
        |> Queries.Alias.for_user(user.id)
        |> Queries.Alias.matching(pattern)
        |> Repo.all

        site_aliases = SiteCommandAlias
        |> Queries.Alias.matching(pattern)
        |> Repo.all

        aliases = user_aliases ++ site_aliases

        {:ok, Helpers.jsonify(aliases)}
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
