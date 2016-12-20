defmodule Cog.Commands.Alias.Move do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "alias-move"

  alias Cog.Repo
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias

  require Cog.Commands.Helpers, as: Helpers

  @description "Moves aliases between visibilities"

  @long_descrption """
  Can also be used to rename an alias. If a visibility is not specified the
  user visibility is first searched and then the site visibility.
  """

  @arguments "<alias-source> <alias-destination>"

  @examples """
  Move alias from user to site:

    alias move user:my-awesome-alias site

  Move and rename alias:

    alias move user:my-awesome-alias site:my-really-awesome-alias

  Rename alias:

    alias move my-awesome-alias my-really-awesome-alias
  """

  @output_description "Returns serialized aliases for both the source and destination"

  @output_example """
  [
    {
      "source": {
        "visibility": "user",
        "pipeline": "echo \\\"My Awesome Alias\\\"",
        "name": "my-awesome-alias"
      },
      "destination": {
        "visibility": "site",
        "pipeline": "echo \\\"My Awesome Alias\\\"",
        "name": "my-awesome-alias"
      }
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:alias-move allow"

  def handle_message(req, state) do
    user_id = req.user["id"]

    result = case Helpers.get_args(req.args, 2) do
      {:ok, [src, dest]} ->
        case Helpers.get_command_alias(user_id, src) do
          nil ->
            {:error, {:alias_not_found, src}}
          src_alias ->
            results = Repo.transaction(fn ->
              case generate_changeset(user_id, src_alias, dest) do
                {:ok, changeset} ->
                  move_alias(changeset, src_alias)
                error ->
                  error
              end
            end)

            case results do
              {:ok, command_alias} ->
                src_json = Helpers.jsonify(src_alias)
                dest_json = Helpers.jsonify(command_alias)
                {:ok, "alias-move", %{source: src_json, destination: dest_json}}
              error ->
                error
            end
        end
      error ->
        error
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Helpers.error(err), state}
    end
  end

  # Generates the changeset for the alias based on the alias type(site or user).
  defp generate_changeset(user_id, %SiteCommandAlias{}=src, "user"),
    do: {:ok, UserCommandAlias.changeset(%UserCommandAlias{}, %{name: src.name, pipeline: src.pipeline, user_id: user_id})}
  defp generate_changeset(_, %UserCommandAlias{}, "user"),
    do: {:error, :alias_in_user}
  defp generate_changeset(_user_id, %UserCommandAlias{}=src, "site"),
    do: {:ok, SiteCommandAlias.changeset(%SiteCommandAlias{}, %{name: src.name, pipeline: src.pipeline})}
  defp generate_changeset(_, %SiteCommandAlias{}, "site"),
    do: {:error, :alias_in_site}
  defp generate_changeset(user_id, src, "user:" <> user_alias),
    do: {:ok, UserCommandAlias.changeset(%UserCommandAlias{}, %{name: user_alias, pipeline: src.pipeline, user_id: user_id})}
  defp generate_changeset(_user, src, "site:" <> site_alias),
    do: {:ok, SiteCommandAlias.changeset(%SiteCommandAlias{}, %{name: site_alias, pipeline: src.pipeline})}
  # This bit is called when you just want to rename an alias but leave it in the current visibility
  defp generate_changeset(user_id, %UserCommandAlias{}=user_alias, alias),
    do: generate_changeset(user_id, user_alias, "user:#{alias}")
  defp generate_changeset(user_id, %SiteCommandAlias{}=site_alias, alias),
    do: generate_changeset(user_id, site_alias, "site:#{alias}")

  # Inserts the changeset
  defp move_alias(changeset, src) do
    Repo.delete!(src)

    case Repo.insert(changeset) do
      {:ok, command_alias} ->
        command_alias
      {:error, %{errors: errors}} ->
        Repo.rollback({:db_errors, errors})
    end
  end

end
