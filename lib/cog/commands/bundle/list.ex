defmodule Cog.Commands.Bundle.List do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "bundle-list"

  alias Cog.Repository.Bundles

  @description "List all bundles"

  @output_description "Returns serialized bundles which include summaries of each version and the full attributes of the enabled version"

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

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle-list must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req, state) do
    rendered = Cog.V1.BundlesView.render("index.json", %{bundles: Bundles.bundles})
    {:reply, req.reply_to, "bundle-list", rendered[:bundles], state}
  end

end
