defmodule Cog.V1.BundlesView do
  use Cog.Web, :view

  alias Cog.V1.RelayGroupView
  alias Cog.V1.BundleVersionsView

  def render("bundle.json", %{bundle: bundle}=_params) do
    enabled_version = Map.fetch!(bundle, :enabled_version)
    enabled_version = if Ecto.assoc_loaded?(enabled_version) do
      %{enabled_version: render_one(enabled_version, BundleVersionsView, "bundle_version.json", as: :bundle_version)}
    else
      %{}
    end

    relay_groups = if Ecto.assoc_loaded?(bundle.relay_groups) do
      %{relay_groups: render_many(bundle.relay_groups, RelayGroupView, "relay_group.json", as: :relay_group)}
    else
      %{}
    end

    %{id: bundle.id,
      name: bundle.name,
      versions: ordered_version_strings(bundle.versions),
      inserted_at: bundle.inserted_at,
      updated_at: bundle.updated_at}
    |> Map.merge(enabled_version)
    |> Map.merge(relay_groups)
  end
  def render("index.json", %{bundles: bundles}) do
    %{bundles: render_many(bundles, __MODULE__, "bundle.json", as: :bundle)}
  end
  def render("show.json", %{bundle: bundle}) do
    %{bundle: render_one(bundle, __MODULE__, "bundle.json", as: :bundle)}
  end

  ########################################################################

  defp ordered_version_strings(versions) do
    versions
    |> Enum.map(&(&1.version))
    |> Enum.sort
    |> Enum.reverse
    |> Enum.map(&to_string/1)
  end

end
