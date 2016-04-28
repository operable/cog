defmodule Cog.Support.TestCommands.TestEcho do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false, name: "t-echo"

  @moduledoc """
  Repeats whatever it is passed.

  ## Example

      @bot #{Cog.embedded_bundle}:t-echo this is nifty
      > this if nifty

  """

  def handle_message(req, state) do
    {:reply, req.reply_to, echo_string(req.args), state}
  end

  defp echo_string([]), do: ""
  defp echo_string(args) when is_list(args), do: hd(args)
end
