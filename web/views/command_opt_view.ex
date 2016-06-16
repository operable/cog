defmodule Cog.V1.CommandOptView do
  use Cog.Web, :view

  def render("command_opt.json", %{command_opt: command_opt}) do
    %{name: command_opt.name}
  end
end
