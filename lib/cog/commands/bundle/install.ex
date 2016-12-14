defmodule Cog.Commands.Bundle.Install do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "bundle-install"

  alias Cog.Commands.Bundle
  alias Cog.Models.BundleVersion
  alias Cog.Repository.Bundles

  @description "Install latest or specified version of bundle from registry."

  @arguments "<bundle> [<version>]"

  @output_description "Returns top-level data about the newly installed bundle"

  @output_example """
  [
    {
      "versions": [
        {
          "version": "0.5.0",
          "id": "57acacbc-6fa3-4044-ba13-7d7c2cf8e96d",
          "description": "AWS CloudFormation"
        }
      ],
      "updated_at": "2016-12-08T16:16:27",
      "name": "cfn",
      "inserted_at": "2016-12-08T16:16:27",
      "id": "c7033d7c-2b68-4e72-a59d-458234b7c61f"
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle-install must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req = %{args: []}, state),
    do: {:error, req.reply_to, Bundle.error({:not_enough_args, 1}), state}
  def handle_message(req = %{args: [bundle]}, state),
    do: handle_message(%{req | args: [bundle, "latest"]}, state)
  def handle_message(req = %{args: [bundle, version]}, state) do
    result = case Bundles.install_from_registry(bundle, version) do
      {:ok, %BundleVersion{bundle: bundle} = bundle_version} ->
        bundle = %{bundle | versions: [bundle_version]}
        rendered = Cog.V1.BundlesView.render("show.json", %{bundle: bundle})
        {:ok, "bundle-install", rendered[:bundle]}
      {:error, {:db_errors, [version: {"has already been taken", []}]}} ->
        {:error, {:already_installed, bundle, version}}
      {:error, error} ->
        {:error, error}
    end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:error, err} ->
        {:error, req.reply_to, Bundle.error(err), state}
    end
  end
  def handle_message(req, state),
    do: {:error, req.reply_to, Bundle.error({:too_many_args, 1}), state}
end
