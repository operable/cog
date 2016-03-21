defmodule Cog.V1.BootstrapView do
  use Cog.Web, :view

  def render("status.json", %{status: status}) do
    %{bootstrap: %{bootstrap_status: status}}
  end

  def render("bootstrapped.json", _) do
    %{errors: %{bootstrap: "Already bootstrapped"}}
  end

  def render("bootstrap.json", %{user: user}) do
    %{bootstrap: %{username: user.username,
                   password: user.password}}
  end
end
