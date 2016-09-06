defmodule Cog.Commands.User do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Commands.User.{AttachHandle, DetachHandle, Info, List, ListHandles}
  require Cog.Commands.Helpers, as: Helpers

  Helpers.usage(:root)

  @description "Manage Cog users and chat handles"

  @note """
  For creation and deletion of users, please continue to use `cogctl`.
  """

  @arguments "<subcommand>"

  @subcommands %{
    "list" => "List all users (default)",
    "info <username>" => "Show detailed information on a given user",
    "list-handles" => "List all chat handles associated with users",
    "attach-handle <username> <handle>" => "Associate a chat handle with a user",
    "detach-handle <username>" => "Sever association between a chat handle and a user"
  }

  permission "manage_users"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:user must have #{Cog.Util.Misc.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "attach-handle" -> AttachHandle.attach(req, args)
               "detach-handle" -> DetachHandle.detach(req, args)
               "list"          -> List.list(req, args)
               "list-handles"  -> ListHandles.list(req, args)
               "info"          -> Info.info(req, args)
               nil ->
                 if Helpers.flag?(req.options, "help") do
                   show_usage
                 else
                   List.list(req, args)
                 end
               other ->
                 {:error, {:unknown_subcommand, other}}
             end

     case result do
       {:ok, template, data} ->
         {:reply, req.reply_to, template, data, state}
       {:ok, data} ->
         {:reply, req.reply_to, data, state}
       {:error, err} ->
         {:error, req.reply_to, error(err), state}
     end
  end

  ########################################################################

  defp error(:invalid_handle),
    do: "Invalid chat handle"
  defp error(error),
    do: Helpers.error(error)

end
