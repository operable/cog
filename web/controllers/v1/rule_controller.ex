defmodule Cog.V1.RuleController do
  use Cog.Web, :controller
  alias Cog.Models.Command
  alias Cog.Models.Rule
  alias Cog.Repository.Bundles
  alias Cog.RuleIngestion
  require Logger

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def create(conn, %{"rule" => rule_text}) do
    case RuleIngestion.ingest(rule_text, Bundles.site_bundle_version) do
      {:ok, rule} ->
        conn
        |> put_status(:created)
        |> render("rule.json", rule: rule)
      {:error, errors} ->
        for error <- errors do
          Logger.error("Error ingesting \"#{rule_text}\": #{inspect error}")
        end
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => keyword_list_to_string_map(errors)})
    end
  end

  def show(conn, %{"for-command" => command}) do
    case Command.parse_name(command) do
      {:error, {:command_not_found, command}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: "Command #{inspect command} not found"})
      {:ok, command} ->
        rules = Repo.all(Ecto.assoc(command, :rules))
        render(conn, "index.json", rules: rules)
    end
  end

  def show(conn, params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{"errors" => "Unknown parameters #{inspect params}"})
  end

  def delete(conn, %{"id" => id}) do
    Rule |> Repo.get!(id) |> Repo.delete!
    send_resp(conn, :no_content, "")
  end

  @doc """
  Converts a keyword list into a string-keyed map, converting multiple
  values into a single list value in the final map.

  Assumes values are all encodable as JSON, as that's what this will
  eventually feed into.

  Multi-valued lists will be in the same order as the original values
  in the keyword list.

  Example:

      iex> keyword_list_to_string_map([stuff: "foo", things: "bar"])
      %{"stuff" => "foo", "things" => "bar"}

      iex> keyword_list_to_string_map([stuff: "foo", stuff: "bar"])
      %{"stuff" => ["foo", "bar"]}

  """
  def keyword_list_to_string_map(kw_list) do
    Enum.reduce(Keyword.keys(kw_list), %{}, fn(k, acc) ->
      Map.put(acc, Atom.to_string(k), Keyword.get_values(kw_list, k))
    end)
  end

end
