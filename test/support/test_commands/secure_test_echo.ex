defmodule Cog.Support.TestCommands.SecureTestEcho do
  use Cog.GenCommand.Base, bundle: Cog.embedded_bundle, name: "st-echo"

  @moduledoc """
  Repeats whatever it is passed.

  ## Example

      @bot #{Cog.embedded_bundle}:secure-test-echo this is nifty
      > this if nifty

  """

  permission "st-echo"
  rule "when command is #{Cog.embedded_bundle}:st-echo must have #{Cog.embedded_bundle}:st-echo"

  def handle_message(req, state) do
    {:reply, req.reply_to, echo_string(req.args), state}
  end

  defp echo_string([]), do: ""
  defp echo_string(args) when is_list(args), do: hd(args)
end
