defmodule Cog.Command.Pipeline.Plan do

  @type t :: %__MODULE__{command: %Cog.Models.Command{},
                         invocation_id: String.t,
                         invocation_text: String.t,
                         invocation_step: String.t,
                         options: %{String.t => term},
                         args: [term],
                         cog_env: Map.t | [Map.t]}
  defstruct [
    command: nil,
    invocation_id: nil,
    invocation_text: nil,
    invocation_step: nil,
    options: %{},
    args: [],
    cog_env: nil]

end
