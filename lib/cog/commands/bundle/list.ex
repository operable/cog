defmodule Cog.Commands.Bundle.List do
  alias Cog.Repository.Bundles
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage """
  List all bundles.

  USAGE
    bundle list [FLAGS]

  FLAGS
    -h, --help  Display this usage info
  """

  def list(%{options: %{"help" => true}}, _args) do
    show_usage
  end
  def list(_req, _args) do
    rendered = Cog.V1.BundlesView.render("index.json", %{bundles: Bundles.bundles})
    {:ok, "bundle-list", rendered[:bundles]}
  end

end
