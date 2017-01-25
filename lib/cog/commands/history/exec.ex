defmodule Cog.Commands.HistoryExec do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle,
    name: "history-exec"

  alias Cog.Chat.Message
  alias Cog.Repository.PipelineHistory, as: HistoryRepo
  alias Cog.Repository.Users, as: UserRepo

  @description "Re-execute pipeline history entry"

  @arguments "index"

  # Allow any user to run history exec
  rule "when command is #{Cog.Util.Misc.embedded_bundle}:history-exec allow"

  def handle_message(%{args: [index]} = req, state) when is_integer(index) do
    case fetch_entry(req, index) do
      nil ->
        {:error, req.reply_to, "Unknown history index: #{index}", state}
      entry ->
        replace_self(req, entry, state)
    end
  end
  def handle_message(req, state) do
    {:error, req.reply_to, "Invalid or missing pipeline history index.", state}
  end

  defp fetch_entry(req, index) do
    {:ok, app_user} = UserRepo.by_username(req.requestor.handle)
    HistoryRepo.history_entry(app_user.id, index)
  end

  defp replace_self(req, entry, state) do
    message = %Message{id: String.replace(UUID.uuid4(), "-", ""),
                       room: req.room,
                       user: req.requestor,
                       text: entry.text,
                       provider: entry.provider}
    {:replace_invocation, message, state}
  end

end
