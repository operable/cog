defmodule Cog.V1.BootstrapController do
  use Cog.Web, :controller

  alias Cog.Bootstrap

  def index(conn, _params) do
    conn
    |> render("status.json", status: Bootstrap.is_bootstrapped?)
  end

  def create(conn, _params) do
    cond do
      Bootstrap.is_bootstrapped? ->
        conn
        |> put_status(423)
        |> render("bootstrapped.json", [])
      :global.set_lock({:cog_bootstrap, self()}, [node()]) ->
        {:ok, user} = Bootstrap.bootstrap()
        :global.del_lock({:cog_bootstrap, self()})
        conn
        |> render("bootstrap.json", user: user)
      true ->
        conn
        |> put_status(423)
        |> render("bootstrapped.json", [])
    end
  end

end
