defmodule Spanner.Command.Response do

  use Spanner.Marshalled

  defmarshalled [:room, :status, :status_message, :body, :bundle, :template]

end
