defmodule Cog.V1.BundlesView do
  use Cog.Web, :view

  alias Cog.V1.RelayGroupView
  alias Cog.V1.BundleVersionView

  def render("bundle.json", %{bundle: bundle}=_params) do
    enabled_version = Map.fetch!(bundle, :enabled_version)
    enabled_version = if Ecto.assoc_loaded?(enabled_version) do
      %{enabled_version: render_one(enabled_version, BundleVersionView, "bundle_version.json", as: :bundle_version)}
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
      versions: ordered_versions(bundle.versions),
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

  defp ordered_versions(versions) do
    versions
    |> Enum.sort_by(&(&1.version), &>=/2)
    |> Enum.map(&(%{"id" => &1.id,
                    "version" => to_string(&1.version)}))
  end

end
