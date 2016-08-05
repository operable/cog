defmodule Cog.Command.ReplyHelper do
  alias Cog.Chat.Adapter
  alias Cog.Template

  @doc """
  Renders a template and sends it to the originating room
  """
  @spec send_template(map, String.t, map, Connection.connection) :: :ok | {:error, any}
  def send_template(request, template_name, context, conn) do
    case Template.render(request["adapter"], template_name, context) do
      {:ok, message} ->
        Adapter.send(conn, request.adapter, request.room, message)
      error ->
        error
    end
  end

end
