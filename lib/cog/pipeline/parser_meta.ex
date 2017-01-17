defmodule Cog.Pipeline.ParserMeta do
  @moduledoc """
  Metadata accumulated during command parsing that is of use in
  downstream processing.
  """

  @type t :: %__MODULE__{bundle_name: String.t,
                         command_name: String.t,
                         version: Version.t,
                         bundle_version_id: String.t, # UUID, really
                         full_command_name: String.t,
                         options: [%Cog.Models.CommandOption{}],
                         rules: [%Cog.Models.Rule{}]}
  defstruct [bundle_name: nil,
             command_name: nil,
             version: nil,
             bundle_version_id: nil,
             full_command_name: nil,
             options: [],
             rules: []]

  def new(bundle_name, command_name, version, bundle_version_id, options, rules) do
    %__MODULE__{bundle_name: bundle_name,
                command_name: command_name,
                version: version,
                bundle_version_id: bundle_version_id,
                full_command_name: "#{bundle_name}:#{command_name}",
                options: options,
                rules: rules}
  end

end
