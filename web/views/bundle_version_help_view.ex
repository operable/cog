defmodule Cog.BundleVersionHelpView do
  use Cog.Web, :view

  def render("bundle_version.json", %{bundle_version: bundle_version}) do
    %{id: bundle_version.id,
      bundle_id: bundle_version.bundle.id,
      name: bundle_version.bundle.name,
      description: bundle_version.description,
      long_description: bundle_version.long_description,
      author: bundle_version.author,
      homepage: bundle_version.homepage,
      version: to_string(bundle_version.version),
      commands: render_many(bundle_version.commands, __MODULE__, "command_version.json", as: :command_version),
      config_file: bundle_version.config_file}
  end
  def render("command_version.json", %{command_version: command_version}) do
    %{name: command_version.command.name,
      description: command_version.description}
  end
end
