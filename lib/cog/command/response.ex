defmodule Cog.Command.Response do

  use Cog.Marshalled

  defmarshalled [:room, :status, :status_message, :body, :bundle, :template]

end
