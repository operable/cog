defmodule Cog.Commands.User do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.embedded_bundle

  alias Cog.Commands.User.{Info, List}

  require Cog.Commands.Helpers, as: Helpers
  require Logger

  Helpers.usage :root, """
  View information on Cog users

  USAGE

    user [subcommand]

  FLAGS
    -h, --help  Display this usage info

  SUBCOMMANDS
    info      Show detailed information on a given user
    list      List all users (default)
  """

  permission "manage_users"

  rule "when command is #{Cog.embedded_bundle}:user must have #{Cog.embedded_bundle}:manage_users"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "list" -> List.list(req, args)
               "info" -> Info.info(req, args)
               nil ->
                 if Helpers.flag?(req.options, "help") do
                   show_usage
                 else
                   List.list(req, args)
                 end
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

  defp error(error),
    do: Helpers.error(error)

end
