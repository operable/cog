defmodule Cog.Command.Pipeline.ParserMeta do
  @moduledoc """
  Metadata accumulated during command parsing that is of use in
  downstream processing.
  """

  @type t :: %__MODULE__{bundle_name: String.t,
                         command_name: String.t,
                         version: Version.t,
                         bundle_version_id: String.t, # UUID, really
                         bundle_config_version: integer(),
                         full_command_name: String.t,
                         options: [%Cog.Models.CommandOption{}],
                         rules: [%Cog.Models.Rule{}]}
  defstruct [bundle_name: nil,
             command_name: nil,
             version: nil,
             bundle_version_id: nil,
             bundle_config_version: 0,
             full_command_name: nil,
             options: [],
             rules: []]

  def new(bundle_name, command_name, bundle_version, options, rules) do
    %__MODULE__{bundle_name: bundle_name,
                command_name: command_name,
                version: bundle_version.version,
                bundle_version_id: bundle_version.id,
                bundle_config_version: bundle_version.config_file["cog_bundle_version"],
                full_command_name: "#{bundle_name}:#{command_name}",
                options: options,
                rules: rules}
  end

end
