defmodule Cog.V1.BootstrapController do
  use Cog.Web, :controller

  alias Cog.Bootstrap

  def index(conn, _params) do
    render(conn, "status.json", status: Bootstrap.is_bootstrapped?)
  end

  def create(conn, params) do
    cond do
      Bootstrap.is_bootstrapped? ->
        conn
        |> put_status(423)
        |> render("bootstrapped.json", [])
      :global.set_lock({:cog_bootstrap, self()}, [node()]) ->
        user_params = Map.get(params, "user", %{})
        response = case Bootstrap.bootstrap(user_params) do
                     {:ok, user} ->
                       %{user: user}
                     {:error, error} ->
                       %{error: error}
                   end

        :global.del_lock({:cog_bootstrap, self()})
        conn
        |> put_status(response_status(response))
        |> render("bootstrap.json", response)
      true ->
        conn
        |> put_status(423)
        |> render("bootstrapped.json", [])
    end
  end

  defp response_status(%{user: _user}), do: 200
  defp response_status(%{error: _error}), do: 422

end
