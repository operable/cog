defmodule Cog.Commands.Bundle.Versions do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "bundle-versions"

  alias Cog.Commands.Bundle
  alias Cog.Repository.Bundles

  @description "Lists currently installed versions of a given bundle"

  @arguments "<bundle>"

  @output_description "Returns serialized bundle versions. Bundle attributes are trucated in example."

  @output_example """
  [
    {
      "version": "0.17.0",
      "updated_at": "2016-12-13T06:15:40",
      "name": "operable",
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle-versions must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req = %{args: [bundle_name]}, state) do
    result = case Bundles.bundle_by_name(bundle_name) do
      nil ->
        {:error, {:resource_not_found, "bundle", bundle_name}}
      bundle ->
        versions = Bundles.versions(bundle)
        rendered = Cog.V1.BundleVersionView.render("index.json", %{bundle_versions: versions})
        {:ok, "bundle-versions", rendered[:bundle_versions]}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Bundle.error(err), state}
    end
  end
  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Bundle.error({:not_enough_args, 1}), state}
  def handle_message(req, state),
    do: {:error, req.reply_to, Bundle.error({:too_many_args, 1}), state}

end
