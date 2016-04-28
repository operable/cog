defmodule Cog.V1.MemoryServiceController do
  use Cog.Web, :controller
  require Logger

  plug Cog.Plug.ServiceAuthentication
  import Cog.Plug.Util, only: [get_service_token: 1]

  alias Cog.Command.Service.Memory

  def show(conn, %{"key" => key}) do
    service_token = get_service_token(conn)
    case Memory.fetch(service_token, key) do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> json(result)
      {:error, :unknown_key} ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "key not found"})
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{"error" => inspect(reason)})
    end
  end

  def update(conn, %{"key" => key}) do
    service_token = get_service_token(conn)
    value = case conn.body_params do
              %{"_json" => non_object_value} ->
                non_object_value
              object ->
                object
            end

    case Memory.replace(service_token, key, value) do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> json(result)
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{"error" => inspect(reason)})
    end
  end

  def delete(conn, %{"key" => key}) do
    service_token = get_service_token(conn)
    case Memory.delete(service_token, key) do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> json(result)
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{"error" => inspect(reason)})
    end
  end

  def change(conn, %{"key" => key, "op" => operator, "value" => value}) do
    service_token = get_service_token(conn)

    result = case operator do
               "accum" ->
                 Memory.accum(service_token, key, value)
               "join" ->
                 Memory.join(service_token, key, value)
             end

    case result do
      {:ok, value} ->
        conn
        |> put_status(:ok)
        |> json(value)
      {:error, :value_not_list} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"error" => "Must use lists for the #{operator} operation"})
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{"error" => inspect(reason)})
    end
  end

end
