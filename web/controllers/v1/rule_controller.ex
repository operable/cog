defmodule Cog.V1.RuleController do
  use Cog.Web, :controller

  require Logger

  alias Cog.RuleIngestion
  alias Cog.Models.Rule

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def create(conn, %{"rule" => rule_text}) do
    case RuleIngestion.ingest(rule_text) do
      {:ok, rule} ->
        conn
        |> put_status(:created)
        |> json(%{"id" => rule.id,
                  "rule" => rule_text})
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
    rules = Repo.all(Cog.Queries.Command.rules_for_cmd(command))
    case format_response(rules) do
      {:ok, result} ->
        json(conn, %{"rules" => result})
      {:error, err} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors" => err})
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

  defp build_permission_expressions(rules) do
    build_permission_expressions(rules, [])
  end

  defp build_permission_expressions([rule | rest], strings) do
    new_strings = [build_single_expr(rule)] ++ strings
    build_permission_expressions(rest, new_strings)
  end
  defp build_permission_expressions([], strings) do
    strings
  end

  defp build_single_expr(%Cog.Models.Rule{}=rule) do
    ast = Piper.Permissions.Parser.json_to_rule!(rule.parse_tree)
    %{id: rule.id,
      command: ast.command,
      rule: "#{ast}"}
  end

  defp format_response([]), do: {:error, "No rules for command found"}
  defp format_response(response), do: {:ok, build_permission_expressions(response)}

end
