defmodule Cog.V1.BundleDynamicConfigView do
  use Cog.Web, :view

  def render("show.json", %{dynamic_config: dynamic_config}) do
    %{dynamic_configuration: %{bundle_id: dynamic_config.bundle.id,
                               bundle_name: dynamic_config.bundle.name,
                               config: dynamic_config.config}}
  end

end
