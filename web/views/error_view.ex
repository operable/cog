defmodule Cog.ErrorView do
  use Cog.Web, :view

  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("404.json", _assigns) do
    "Object not found"
  end

  def render("500.html", _assigns) do
    "Server internal error"
  end

  def render("422.json", %{error: msg}) do
    %{error: msg}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render "500.html", assigns
  end
end
