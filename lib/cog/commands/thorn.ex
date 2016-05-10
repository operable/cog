defmodule Cog.Commands.Thorn do
  @moduledoc """
  This command replaces `Th` following a word boundary with þ

  ## Example

      @bot operable:thorn foo-Thbar-Thbaz
  """
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  rule "when command is #{Cog.embedded_bundle}:thorn allow"

  @message "The thorn command has been deprecated and will be removed in a future release"

  def handle_message(req, state) do
    {:reply, req.reply_to, @message, state}
  end
end
