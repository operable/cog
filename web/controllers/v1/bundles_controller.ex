defmodule Cog.V1.BundlesController do
  use Cog.Web, :controller

  alias Spanner.Config
  alias Cog.Models.Bundle

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.Util.Misc.embedded_bundle}:manage_commands"

  alias Cog.Repository

  def index(conn, _params),
    do: render(conn, "index.json", %{bundles: Repository.Bundles.bundles})

  def show(conn, %{"id" => id}) do
    case Repository.Bundles.bundle(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Bundle #{id} not found"})
      %Bundle{}=bundle ->
        render(conn, "show.json", %{bundle: bundle})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repository.Bundles.bundle(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Bundle #{id} not found"})
      %Bundle{}=bundle ->
        case Repository.Bundles.delete(bundle) do
          {:ok, _} ->
            send_resp(conn, 204, "")
          {:error, {:enabled_version, version}} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Cannot delete #{bundle.name} bundle, because version #{version} is currently enabled"})
          {:error, {:protected_bundle, name}} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Cannot delete #{name} bundle"})
        end
    end
  end

  def create(conn, %{"bundle" => params}) do
    case install_bundle(params) do
      {:ok, bundle_version, warnings} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Cog.Router.Helpers.bundle_version_path(conn, :show, bundle_version.bundle.id, bundle_version.id))
        |> render(Cog.V1.BundleVersionView, "show.json", %{bundle_version: bundle_version, warnings: warnings})
      {:error, err} ->
        send_failure(conn, err)
    end
  end
  def create(conn, _params),
    do: send_resp(conn, 400, "")

  def install(conn, %{"bundle" => bundle, "version" => version}) do
    case Repository.Bundles.install_from_registry(bundle, version) do
      {:ok, bundle_version} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Cog.Router.Helpers.bundle_version_path(conn, :show, bundle_version.bundle.id, bundle_version.id))
        |> render(Cog.V1.BundleVersionView, "show.json", %{bundle_version: bundle_version, warnings: []})
      {:error, error} ->
        send_failure(conn, error)
    end
  end

  ########################################################################
  # Bundle Creation Helpers

  defp install_bundle(params) do
    with {:ok, config}                 <- parse_config(params),
         {:ok, install_type}           <- install_type(params),
         {:ok, valid_config, warnings} <- validate_config(config),
         {:ok, params}                 <- merge_config(params, valid_config),
         {:ok, bundle}                 <- Repository.Bundles.install(install_type, params) do
           {:ok, bundle, warnings}
    end
  end

  defp parse_config(%{"config" => config}) when is_map(config),
    do: {:ok, config}
  defp parse_config(%{"config_file" => %Plug.Upload{}=config_file}) do
    with :ok <- validate_file_format(config_file),
         do: parse_config_file(config_file)
  end
  defp parse_config(_),
    do: {:error, :no_config}

  defp install_type(%{"force" => true}),
    do: {:ok, :force}
  defp install_type(_),
    do: {:ok, :normal}

  # If we have a file, check to see if the filename has the correct extension
  defp validate_file_format(%Plug.Upload{filename: filename}) do
    if Config.config_extension?(filename) do
      :ok
    else
      {:error, :unsupported_format}
    end
  end

  # If we have something to parse, parse it
  defp parse_config_file(%Plug.Upload{path: path}) do
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
      {:ok, validated_config} ->
        {:ok, validated_config, []}
      {:warning, validated_config, warnings} ->
        {:ok, validated_config, warnings}
      {:error, errors, warnings} ->
        {:error, {:validation_error, errors, warnings}}
    end
  end

  # Construct params for creating a bundle record
  defp merge_config(params, config) do
    merged_params = params
    |> Map.drop(["config", "config_file"])
    |> Map.merge(Map.take(config, ["name", "version", "description"]))
    |> Map.put("config_file", config)

    {:ok, merged_params}
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
    {:bad_request, %{error: "Missing bundle config."}}
  end
  defp error(:unsupported_format) do
    msg = ~s(Unsupported file format. Please upload a file in one of the following formats: #{Enum.join(Spanner.Config.config_extensions, ", ")})
    {:unsupported_media_type, %{error: msg}}
  end
  defp error({:parse_error, errors}) do
    msg = ["Unable to parse config file."]
    {:unprocessable_entity, %{errors: msg ++ errors}}
  end
  defp error({:validation_error, errors, warnings}) do
    msg = ["Invalid config file."]
    errors = Enum.map(errors, fn({msg, meta}) -> ~s(Error near #{meta}: #{msg}) end)
    warnings = Enum.map(warnings, fn({msg, meta}) -> ~s(Warning near #{meta}: #{msg}) end)
    {:unprocessable_entity, %{errors: msg ++ errors, warnings: warnings}}
  end
  defp error({:db_errors, [{_, {"has already been taken", []}}]=errors}) do
    # A bit fragile, relying as it does on the specific message that
    # Ecto uses by default for unique constraint violations, but
    # allows us to fail with a more appropriate HTTP 409
    msg = ["Could not save bundle."]
    errors = Enum.map(errors, fn({field, {message, []}}) -> "#{Atom.to_string(field)} #{message}" end)
    {:conflict, %{errors: msg ++ errors}}
  end
  defp error({:db_errors, errors}) do
    msg = ["Could not save bundle."]
    errors = Enum.map(errors, fn({_, {message, []}}) -> message end)
    {:unprocessable_entity, %{errors: msg ++ errors}}
  end
  defp error({:not_found, bundle}) do
    msg = ["Bundle #{inspect bundle} not found."]
    {:not_found, %{errors: msg}}
  end
  defp error({:not_found, bundle, version}) do
    msg = ["Bundle #{inspect bundle} version #{inspect version} not found."]
    {:not_found, %{errors: msg}}
  end
  defp error(err) do
    msg = inspect(err)
    {:unprocessable_entity, %{error: msg}}
  end

end
