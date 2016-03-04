defmodule Cog.Commands.Alias.Mv do
  alias Cog.Repo
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias
  alias Cog.Commands.Helpers

  @moduledoc """
  Moves aliases between visibilities. Optionally renames the alias. Subcommand
  for alias. If a visibility is not specified the user visibility is first searched
  and then the site visibility.

  usage:
  alias mv <alias-src> <alias-destination>

  example:
  alias mv user:my-awesome-alias site
  alias mv user:my-awesome-alias site:my-really-awesome-alias
  alias mv my-awesome-alias my-really-awesome-alias
  """

  @doc """
  Entry point for moving an alias.
  Takes a cog request and argument list.
  returns {:ok, <msg>} on success {:error, <err>} on failure.
  """
  def mv_command_alias(req, arg_list) do
    case Helpers.get_args(arg_list, 2) do
      {:ok, [src, dest]} ->
        user = Helpers.get_user(req.requestor)
        case Helpers.get_command_alias(user, src) do
          nil ->
            Helpers.error(:alias_not_found, src)
          src_alias ->
            results = Repo.transaction(fn ->
              case generate_changeset(user, src_alias, dest) do
                {:ok, changeset} ->
                  mv_alias(changeset, src_alias)
                error ->
                  error
              end
            end)

            case results do
              {:ok, command_alias} ->
                src_json = Helpers.jsonify(src_alias)
                dest_json = Helpers.jsonify(command_alias)
                {:ok, "alias-mv", %{source: src_json, destination: dest_json}}
              error ->
                error
            end
        end
      error ->
        error
    end
  end

  # Generates the changeset for the alias based on the alias type(site or user).
  defp generate_changeset(user, %SiteCommandAlias{}=src, "user"),
    do: {:ok, UserCommandAlias.changeset(%UserCommandAlias{}, %{name: src.name, pipeline: src.pipeline, user_id: user.id})}
  defp generate_changeset(_, %UserCommandAlias{}, "user"),
    do: {:error, :alias_in_user}
  defp generate_changeset(_user, %UserCommandAlias{}=src, "site"),
    do: {:ok, SiteCommandAlias.changeset(%SiteCommandAlias{}, %{name: src.name, pipeline: src.pipeline})}
  defp generate_changeset(_, %SiteCommandAlias{}, "site"),
    do: {:error, :alias_in_site}
  defp generate_changeset(user, src, "user:" <> user_alias),
    do: {:ok, UserCommandAlias.changeset(%UserCommandAlias{}, %{name: user_alias, pipeline: src.pipeline, user_id: user.id})}
  defp generate_changeset(_user, src, "site:" <> site_alias),
    do: {:ok, SiteCommandAlias.changeset(%SiteCommandAlias{}, %{name: site_alias, pipeline: src.pipeline})}
  # This bit is called when you just want to rename an alias but leave it in the current visibility
  defp generate_changeset(user, %UserCommandAlias{}=user_alias, alias),
    do: generate_changeset(user, user_alias, "user:#{alias}")
  defp generate_changeset(user, %SiteCommandAlias{}=site_alias, alias),
    do: generate_changeset(user, site_alias, "site:#{alias}")

  # Inserts the changeset
  defp mv_alias(changeset, src) do
    Repo.delete!(src)

    case Repo.insert(changeset) do
      {:ok, command_alias} ->
        command_alias
      {:error, %{errors: errors}} ->
        Repo.rollback({:db_errors, errors})
    end
  end

end
