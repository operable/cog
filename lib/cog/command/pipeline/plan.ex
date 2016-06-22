defmodule Cog.Command.Pipeline.Plan do

  @type t :: %__MODULE__{parser_meta: %Cog.Command.Pipeline.ParserMeta{},
                         invocation_id: String.t,
                         invocation_text: String.t,
                         invocation_step: String.t,
                         relay_id: String.t,
                         options: %{String.t => term},
                         args: [term],
                         cog_env: Map.t | [Map.t]}
  defstruct [
    parser_meta: nil,
    invocation_id: nil,
    invocation_text: nil,
    invocation_step: nil,
    relay_id: nil,
    options: %{},
    args: [],
    cog_env: nil]

end
