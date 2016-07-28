defmodule Cog.V1.BundleDynamicConfigView do
  use Cog.Web, :view

  def render("config.json", %{dynamic_config: dynamic_config}) do
    %{bundle_id: dynamic_config.bundle.id,
      bundle_name: dynamic_config.bundle.name,
      layer: dynamic_config.layer,
      name: dynamic_config.name,
      config: dynamic_config.config}
  end

  def render("all.json", %{dynamic_configs: configs}) do
    %{dynamic_configurations: render_many(configs, __MODULE__, "config.json", as: :dynamic_config)}
  end

  def render("show.json", %{dynamic_config: dynamic_config}) do
    %{dynamic_configuration: render_one(dynamic_config, __MODULE__, "config.json", as: :dynamic_config)}
  end

end
