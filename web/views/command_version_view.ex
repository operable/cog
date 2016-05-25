defmodule Cog.V1.CommandVersionView do
  use Cog.Web, :view

  def render("command_version.json", %{command_version: command_version}) do
    %{bundle: command_version.command.bundle.name,
      name: command_version.command.name}
  end

end
