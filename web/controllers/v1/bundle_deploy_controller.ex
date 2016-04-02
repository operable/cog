defmodule Cog.V1.BundleDeployController do
  use Cog.Web, :controller

  alias Spanner.Config

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def deploy(conn, _) do
    result = with {:ok, upload} <- get_upload(conn),
                  :ok           <- validate_file_format(upload.filename),
                  {:ok, config} <- parse_config(upload.path),
                  :ok           <- validate_config(config),
                  :ok           <- persist(config),
               do: deploy(config)

    case result do
      {:ok, response} ->
        send_success(conn, response)
      {:error, err} ->
        send_failure(conn, err)
    end
  end

  # First let's make sure we have a file to work with
  defp get_upload(conn) do
    case conn.params do
      %{"config_file" => %Plug.Upload{}=upload} ->
        {:ok, upload}
      _ ->
        {:error, :no_config}
    end
  end

  # Next we check to see that it's a config file
  defp validate_file_format(filename) do
    if Config.config_file?(filename) do
      :ok
    else
      {:error, :unsupported_format}
    end
  end

  # If all is good we parse the file and stick in conn.assigns
  defp parse_config(path) do
    case Config.Parser.read_from_file(path) do
      {:ok, config} ->
        {:ok, config}
      {:error, errors} ->
        {:error, {:parse_error, errors}}
    end
  end

  # Before we can use the config we validate it's contents
  defp validate_config(config) do
    config_format_version = Map.get(config, "cog_bundle_version", :latest)
    case Config.validate(config, config_format_version) do
      :ok ->
        :ok
      {:error, errors} ->
        {:error, {:validation_error, errors}}
    end
  end

  # Create a new record in the DB for the deploy
  defp persist(_config) do
    :ok
  end

  # If all goes as planned, we can deploy the bundle
  defp deploy(_config) do
    {:ok, "WOOT! WOOT!"}
  end

  # Helper functions

  defp send_success(conn, response) do
    send_resp(conn, 201, response)
  end

  defp send_failure(conn, err) do
    {status, msg} = error(err)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, msg)
    |> halt
  end

  defp error(:no_config) do
    {400, Poison.encode!(%{error: "'config_file' not specified."})}
  end
  defp error(:unsupported_format) do
    msg = ~s(Unsupported file format. Please upload a file in one of the following formats: #{Enum.join(Spanner.Config.config_extensions, ", ")})
    {415, Poison.encode!(%{error: msg})}
  end
  defp error({:parse_error, errors}) do
    msg = "Unable to parse config file."
    {422, Poison.encode!(%{error: msg, additional: errors})}
  end
  defp error({:validation_error, errors}) do
    msg = "Invalid config file."
    errors = Enum.map(errors, fn({msg, meta}) -> ~s(Error near #{meta}: #{msg}) end)
    {422, Poison.encode!(%{error: msg, errors: errors})}
  end

end
