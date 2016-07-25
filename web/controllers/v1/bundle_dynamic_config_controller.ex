defmodule Cog.V1.BundleDynamicConfigController do
  use Cog.Web, :controller

  require Logger

  alias Cog.Router.Helpers
  alias Cog.Repository.Bundles

  plug Cog.Plug.Authentication
  plug Cog.Plug.Authorization, permission: "#{Cog.embedded_bundle}:manage_commands"

  def show_all(conn, %{"bundle_id" => id}),
    do: all_config(conn, id)

  def show_layer(conn, %{"layer" => "base", "name" => _name}),
    do: not_found(conn, "There is only a single base layer") # TODO: Just return it anyway?
  def show_layer(conn, %{"layer" => "base"}=params),
    do: show(conn, Map.put(params, "name", "config"))
  def show_layer(conn, %{"layer" => layer, "name" => _name}=params) when layer in ["room", "user"],
    do: show(conn, params)
  def show_layer(conn, _),
    do: not_found(conn, "Dynamic configuration not found")

  def set_layer(conn, %{"layer" => "base", "name" => _name}),
    do: not_found(conn, "There is only a single base layer") # TODO: Just return it anyway?
  def set_layer(conn, %{"layer" => "base"}=params),
    do: create(conn, Map.put(params, "name", "config"))
  def set_layer(conn, %{"layer" => layer, "name" => _name}=params) when layer in ["room", "user"],
    do: create(conn, params)
  def set_layer(conn, _),
    do: not_found(conn, "Incorrect dynamic configuration layer specification")

  def delete_layer(conn, %{"layer" => "base", "name" => _name}),
    do: not_found(conn, "There is only a single base layer") # TODO: Just return it anyway?
  def delete_layer(conn, %{"layer" => "base"}=params),
    do: delete(conn, Map.put(params, "name", "config"))
  def delete_layer(conn, %{"layer" => layer, "name" => _name}=params) when layer in ["room", "user"],
    do: delete(conn, params)
  def delete_layer(conn, _),
    do: not_found(conn, "Dynamic configuration not found")

  ########################################################################

  defp not_found(conn, message) do
    conn
    |> put_status(:not_found)
    |> json(%{error: message})
  end

  defp all_config(conn, id) do
    case Bundles.bundle(id) do
      nil ->
        not_found(conn, "Bundle #{id} not found")
      bundle ->
        configs = Bundles.dynamic_config_for_bundle(bundle)
        render(conn, "all.json", dynamic_configs: configs)
    end
  end

  defp show(conn, %{"bundle_id" => id, "layer" => layer, "name" => name}) do
    case Bundles.bundle(id) do
      nil ->
        not_found(conn, "Bundle #{id} not found")
      bundle ->
        case Bundles.dynamic_config_for_bundle(bundle, layer, name) do
          nil ->
            not_found(conn, "Dynamic configuration layer #{layer}/#{name} for bundle #{bundle.name} not found")
          config ->
            render(conn, "show.json", dynamic_config: config)
        end
    end
  end

  defp create(conn, %{"bundle_id" => bundle_id}=params) do
    case Bundles.bundle(bundle_id) do
      nil ->
        not_found(conn, "Bundle #{bundle_id} not found")
      bundle ->
        case Bundles.create_dynamic_config_for_bundle(bundle, params) do
          {:ok, dyn_config} ->
            location = case Map.get(params, "layer") do
                         "base" ->
                           Helpers.bundle_dynamic_config_path(conn, :show_layer,
                                                              dyn_config.bundle_id,
                                                              dyn_config.layer, %{})
                         _ ->
                           Helpers.bundle_dynamic_config_path(conn, :show_layer,
                                                              dyn_config.bundle_id,
                                                              dyn_config.layer,
                                                              dyn_config.name, %{})
                       end
            conn
            |> put_status(:created)
            |> put_resp_header("location", location)
            |> render("show.json", dynamic_config: dyn_config)
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render(Cog.ChangesetView, "error.json", changeset: changeset)
        end
    end
  end

  defp delete(conn, %{"bundle_id" => id, "layer" => layer, "name" => name}) do
    case Bundles.bundle(id) do
      nil ->
        not_found(conn, "Bundle #{id} not found")
      bundle ->
        if Bundles.delete_dynamic_config_for_bundle(bundle, layer, name) do
          send_resp(conn, 204, "")
        else
          not_found(conn, "Dynamic configuration layer #{layer}/#{name} for bundle #{bundle.name} not found")
        end
    end
  end
end
