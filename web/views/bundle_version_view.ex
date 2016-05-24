defmodule Cog.V1.BundleVersionView do
  use Cog.Web, :view

  def render("bundle_version.json", %{bundle_version: bundle_version}) do
    %{id: bundle_version.id,
      name: bundle_version.bundle.name,
      version: to_string(bundle_version.version),
      enabled: Cog.Models.BundleVersion.enabled?(bundle_version),
      permissions: render_many(bundle_version.permissions, Cog.V1.PermissionView, "permission.json", as: :permission),
      commands: render_many(bundle_version.commands, Cog.V1.CommandVersionView, "command_version.json", as: :command_version),
      inserted_at: bundle_version.inserted_at,
      updated_at: bundle_version.updated_at}
  end
  def render("index.json", %{bundle_versions: bundle_versions}),
    do: %{bundle_versions: render_many(bundle_versions, __MODULE__, "bundle_version.json", as: :bundle_version)}
  def render("show.json", %{bundle_version: bundle_version, warnings: warnings}) when length(warnings) > 0 do
    warnings = Enum.map(warnings, fn({msg, meta}) -> ~s(Warning near #{meta}: #{msg}) end)
    %{warnings: warnings,
      bundle_version: render_one(bundle_version, __MODULE__, "bundle_version.json", as: :bundle_version)}
  end
  def render("show.json", %{bundle_version: bundle_version}) do
    %{bundle_version: render_one(bundle_version, __MODULE__, "bundle_version.json", as: :bundle_version)}
  end

end
