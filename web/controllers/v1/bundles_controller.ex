defmodule Cog.V1.BundlesController do
  use Cog.Web, :controller

  alias Spanner.Config
  alias Cog.Bundle.Install
  alias Cog.Relay.Relays
  alias Cog.Models.Bundle
  alias Cog.Queries
  alias Cog.Repo

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def index(conn, _params) do
    installed = Repo.all(Queries.Bundles.all)
    render(conn, "index.json", %{bundles: installed})
  end

  def show(conn, %{"id" => id}) do
    case Repo.one(Queries.Bundles.for_id(id)) do
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
      bundle ->
        render(conn, "show.json", %{bundle: bundle})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.one(Queries.Bundles.for_id(id)) do
      nil ->
        send_resp(conn, 404, Poison.encode!(%{error: "Bundle #{id} not found"}))
      %Bundle{name: "operable"} ->
        send_resp(conn, 403, Poison.encode!(%{error: "Cannot delete system bundle"}))
      %Bundle{name: name}=bundle ->
        :ok = Relays.drop_bundle(name)
        {:ok, _} = Repo.transaction(fn -> Repo.delete(bundle.namespace)
                                          Repo.delete(bundle) end)
        send_resp(conn, 204, "")
    end
  end

  def create(conn, _) do
    result = with {:ok, upload} <- get_upload(conn),
                  :ok           <- validate_file_format(upload.filename),
                  {:ok, config} <- parse_config(upload.path),
                  :ok           <- validate_config(config),
               do: persist(config)

    case result do
      {:ok, bundle} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", bundles_path(conn, :show, bundle))
        |> render("show.json", %{bundle: bundle})
      {:error, err} ->
        send_failure(conn, err)
    end
  end

  #### BUNDLE CREATION HELPERS ####

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
    if Config.config_extension?(filename) do
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
    case Config.validate(config) do
      :ok ->
        :ok
      {:error, errors} ->
        {:error, {:validation_error, errors}}
    end
  end

  # Create a new record in the DB for the deploy
  defp persist(%{"name" => name} = config) do
    try do
      Install.install_bundle(%{name: name, config_file: config})
      |> Repo.preload(:commands)
    rescue
      err in [Ecto.InvalidChangesetError] ->
        {:error, {:db_error, err.errors}}
    end
  end

  # Helper functions

  defp send_failure(conn, err) do
    {status, msg} = error(err)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(msg))
    |> halt
  end

  defp error(:no_config) do
    {:bad_request, %{error: "'config_file' not specified. Make sure to use a multipart form and to send your file in the 'config_file' field."}}
  end
  defp error(:unsupported_format) do
    msg = ~s(Unsupported file format. Please upload a file in one of the following formats: #{Enum.join(Spanner.Config.config_extensions, ", ")})
    {:unsupported_media_type, %{error: msg}}
  end
  defp error({:parse_error, errors}) do
    msg = "Unable to parse config file."
    {:unprocessable_entity, %{error: msg, additional: errors}}
  end
  defp error({:validation_error, errors}) do
    msg = "Invalid config file."
    errors = Enum.map(errors, fn({msg, meta}) -> ~s(Error near #{meta}: #{msg}) end)
    {:unprocessable_entity, %{error: msg, additional: errors}}
  end
  defp error({:db_error, errors}) do
    msg = "Could not save bundle."
    errors = Enum.map(errors, fn({_, message}) -> message end)
    {:unprocessable_entity, %{error: msg, additional: errors}}
  end
  defp error(err) do
    msg = inspect(err)
    {:unprocessable_entity, %{error: msg}}
  end

end
