defmodule Cog.V1.BundleDeployController do
  use Cog.Web, :controller

  alias Spanner.Config

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  plug :validate_config_presence
  plug :validate_file_format
  plug :parse_config
  plug :validate_config

  def deploy(conn, _) do
    IO.inspect {"CONFIG", conn}
    send_resp(conn, 200, "WOOT WOOT")
  end

  # First let's make sure we have a file to work with
  defp validate_config_presence(conn, _) do
    case conn.params do
      %{"config_file" => %Plug.Upload{}} ->
        conn
      _ ->
        msg = "'config_file' not specified."
        halt_with_error(conn, 400, Poison.encode!(%{error: msg}))
    end
  end

  # Next we check to see that it's a config file
  defp validate_file_format(conn, _) do
    upload = conn.params["config_file"]

    if Spanner.Config.config_file?(upload.filename) do
      conn
    else
      msg = ~s(Unsupported file format. Please upload a file in one of the following formats: #{Enum.join(Spanner.Config.config_extensions, ", ")})
      halt_with_error(conn, 415, Poison.encode!(%{error: msg}))
    end
  end

  # If all is good we parse the file and stick in conn.assigns
  defp parse_config(conn, _) do
    upload = conn.params["config_file"]

    case Config.Parser.read_from_file(upload.path) do
      {:ok, config} ->
        assign(conn, :config, config)
      {:error, errors} ->
        msg = "Unable to parse config file."
        halt_with_error(conn, 400, Poison.encode!(%{error: msg, errors: errors}))
    end
  end

  # Before we can use the config we validate it's contents
  defp validate_config(conn, _) do
    case Config.validate(conn.assigns.config) do
      :ok ->
        conn
      {:error, errors} ->
        msg = "Invalid config file."
        errors = Enum.map(errors, fn({msg, meta}) -> ~s(Error near #{meta}: #{msg}) end)
        halt_with_error(conn, 400, Poison.encode!(%{error: msg, errors: errors}))
    end
  end

  # Helper functions

  # Halts and responds with with json
  defp halt_with_error(conn, status, msg) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, msg)
    |> halt
  end

end
