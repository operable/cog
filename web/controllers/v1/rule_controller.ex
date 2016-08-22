defmodule Cog.V1.RuleController do
  use Cog.Web, :controller
  alias Cog.Models.Rule
  alias Cog.Repository.Rules
  require Logger

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def index(conn, %{"for-command" => command}) do
    case Rules.rules_for_command(command) do
      {:error, {:command_not_found, command}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: "Command #{command} not found"})
      {:error, {:disabled, command_name}} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: "Command #{command_name} not currently enabled; try enabling a bundle version first"})
      {:ok, rules} ->
        render(conn, "index.json", rules: rules)
    end
  end
  def index(conn, params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{"errors" => "Unknown parameters #{inspect params}"})
  end

  def create(conn, %{"rule" => rule_text}) do
    case Rules.ingest(rule_text) do
      {:ok, rule} ->
        conn
        |> put_status(:created)
        |> render("rule.json", rule: rule)
      {:error, error} ->
        Logger.error("Error ingesting \"#{rule_text}\": #{inspect error}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => keyword_list_to_string_map([error])})
    end
  end

  def show(conn, %{"id" => id}) do
    case Rules.rule(id) do
      nil ->
        send_resp(conn, 404, "")
      rule ->
        conn
        |> render("rule.json", rule: rule)
    end
  end

  def update(conn, %{"id" => id, "rule" => rule_text}) do
    case Rules.replace(id, rule_text) do
      {:ok, rule} ->
        conn
        |> render("rule.json", rule: rule)
      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => keyword_list_to_string_map([error])})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Rules.rule(id) do
      %Rule{}=rule ->
        Rules.delete_or_disable(rule)
        send_resp(conn, :no_content, "")
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Rule #{id} not found"})
    end
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
