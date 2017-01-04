defmodule Cog.Commands.Alias.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "alias-info"

  alias Cog.Models.User
  alias Cog.Queries
  alias Cog.Repo

  require Cog.Commands.Helpers, as: Helpers

  @description "Shows a specific alias"

  @arguments "<alias-name>"

  @examples """
  Showing a specific alias:

    alias info user:my-awesome-alias
  """

  @output_description "Returns a serialized alias"

  @output_example """
  [
    {
      "visibility": "user",
      "pipeline": "echo \\\"My Awesome Alias\\\"",
      "name": "my-awesome-alias"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:alias-info allow"

  def handle_message(req = %{args: [name]}, state) when is_binary(name) do
    user_id = req.user["id"]

    result = case find_alias(name, %User{id: user_id}) do
      {:ok, alias} ->
        {:ok, "alias-info", Helpers.jsonify(alias)}
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

  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Helpers.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Helpers.error({:too_many_args, 1}), state}

  def find_alias(full_name, user) do
    query = case full_name do
      "site:" <> name ->
        Queries.Alias.site_alias_by_name(name)
      "user:" <> name ->
        Queries.Alias.user_alias_by_name(user, name)
      name ->
        Queries.Alias.user_alias_by_name(user, name)
    end

    case Repo.one(query) do
      nil ->
        {:error, :not_found}
      alias ->
        {:ok, alias}
    end
  end
end
