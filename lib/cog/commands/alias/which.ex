defmodule Cog.Commands.Alias.Which do
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias
  alias Cog.Models.SiteCommandAlias

  @moduledoc """
  Returns the visibility of an alias. Subcommand for alias.

  usage:
  alias which <alias-name>

  example:
  alias which my-awesome-alias
  """

  @doc """
  Entry point for which.
  Accepts a cog request and an argument list.
  Returns {:ok, <user | site>} on success or {:error, <err>} on failure.
  """
  def which_command_namespace(req, arg_list) do
    case Helpers.get_args(arg_list, 1) do
      {:ok, [alias]} ->
        user = Helpers.get_user(req.requestor)
        case Helpers.get_command_alias(user, alias) do
          nil ->
            {:error, {:alias_not_found, alias}}
          %UserCommandAlias{} ->
            {:ok, "alias-which", %{visibility: "user"}}
          %SiteCommandAlias{} ->
            {:ok, "alias-which", %{visibility: "site"}}
        end
      error ->
        error
    end
  end
end
