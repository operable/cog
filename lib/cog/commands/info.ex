defmodule Cog.Commands.Info do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  @description "Display information about the current running instance of Cog."

  @output_example """
  [
    {
      "embedded_bundle_version": "0.18.0",
      "elixir_version": "1.3.4",
      "cog_version": "0.18.0",
      "bundle_config_version": 5
    }
  ]
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:info allow"

  def handle_message(req, state) do
    info = %{
      cog_version: Keyword.get(Mix.Project.config(), :version),
      elixir_version: System.build_info().version,
      embedded_bundle_version: Application.fetch_env!(:cog, :embedded_bundle_version),
      bundle_config_version: Spanner.Config.current_config_version()
    }

    {:reply, req.reply_to, "info", info, state}
  end
end
