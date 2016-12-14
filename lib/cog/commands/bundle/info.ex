defmodule Cog.Commands.Bundle.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "bundle-info"

  alias Cog.Commands.Bundle
  alias Cog.Repository.Bundles

  @description "Show detailed information about a specific bundle"

  @arguments "<bundle>"

  @output_description "Returns serialized bundle, which includes summary of each version."

  @output_example """
  [
    {
      "versions": [
        {
          "version": "0.17.0",
          "id": "5beb52b2-582b-4da7-9604-ae402df90186",
          "description": "Core chat commands for Cog"
        }
      ],
      "updated_at": "2016-12-07T22:19:04",
      "relay_groups": [],
      "name": "operable",
      "inserted_at": "2016-12-07T22:19:04",
      "id": "8d9aa4e0-3e7d-40c3-94c0-ac8b5190af55",
      "enabled_version": {
        "version": "0.17.0",
        "updated_at": "2016-12-13T06:01:02",
        "name": "operable"
      }
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle-info must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req = %{args: [bundle_name]}, state) do
    result = case Bundles.bundle_by_name(bundle_name) do
      nil ->
        {:error, {:resource_not_found, "bundle", bundle_name}}
      bundle ->
        rendered = Cog.V1.BundlesView.render("show.json", %{bundle: bundle})
        {:ok, "bundle-info", rendered[:bundle]}
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
