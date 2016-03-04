defmodule Cog.Commands.Alias.New do
  alias Cog.Repo
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias

  @moduledoc """
  Create new aliases. Subcommand for alias.

  usage:
  alias new <alias-name> <alias-definition>

  example:
  alias new my-awesome-alias "echo \"My awesome alias\""
  """

  @doc """
  Entry point. Creates an alias.
  Takes a cog request and argument list.
  returns {:ok, <msg>} on success and {:error, <err>} on error.
  """
  def create_new_user_command_alias(req, arg_list) do
    case Helpers.get_args(arg_list, 2) do
      {:ok, [alias_name, pipeline]} ->
        user = Helpers.get_user(req.requestor)
        changeset = UserCommandAlias.changeset(%UserCommandAlias{}, %{name: alias_name, pipeline: pipeline, user_id: user.id})

        case Repo.insert(changeset) do
          {:ok, command_alias} ->
            {:ok, "alias-new", Helpers.jsonify(command_alias)}
          {:error, %{errors: errors}} ->
            {:error, {:db_errors, errors}}
        end
      error ->
        error
    end
  end
end
