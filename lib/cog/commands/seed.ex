defmodule Cog.Command.Seed do
  use Cog.GenCommand.Base, bundle: Cog.embedded_bundle,
                               enforcing: false

  alias Cog.Command.Request
  require Logger

  @moduledoc """
  Seed a pipeline with arbitrary data.

  Accepts a single string argument, which must be valid JSON for
  either a map or a list of maps.

  Though some values may be able to be typed without enclosing quotes,
  it is highly recommended to single-quote your entire string.

  Best used for debugging and experimentation.

  Examples:

      !seed '{"thing":"stuff"}' | echo $thing
      > stuff

      !seed '[{"thing":"stuff"},{"thing":"more stuff"}]' | echo $thing
      > stuff
      > more stuff

  """
  def handle_message(%Request{args: [input]}=req, state) when not(is_binary(input)),
    do: {:error, req.reply_to, "Argument must be a string", state}
  def handle_message(%Request{args: [input]}=req, state) do
    case Poison.decode(input) do
      {:ok, value} when is_map(value) ->
        {:reply, req.reply_to, value, state}
      {:ok, value} when is_list(value) and value != [] ->
        if Enum.all?(value, &is_map/1) do
          {:reply, req.reply_to, value, state}
        else
          {:error, req.reply_to, "All values in a JSON list must be maps", state}
        end
      {:ok, _} ->
        {:error, req.reply_to, "JSON must be a map or a list of maps", state}
      {:error, _} ->
        {:error, req.reply_to, "Bad input! Please supply valid JSON", state}
    end
  end
  def handle_message(req, state),
    do: {:error, req.reply_to, "Please supply a single argument", state}

end
