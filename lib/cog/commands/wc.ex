defmodule Cog.Commands.Wc do
  @moduledoc """
  This command allows the user to count the number of words or lines in the input string.
    wc [--words | --lines]  <input string>

  Examples:
  > @bot wc --words "Hey, what will we do today?"
  > @bot wc --lines "From time to time
  The clouds give rest
  To the moon-beholders."
  """
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false

  option "words", type: "bool", required: false
  option "lines", type: "bool", required: false

  def handle_message(req, state) do
    {:reply, req.reply_to, count_items(req.args, req.options), state}
  end

  def count_items([inputStr | _], options) do
    case options do
      %{"words" => true} ->
        %{words: Enum.count(String.split(inputStr))}
      %{"lines" => true} ->
        %{lines: Enum.count(String.split(inputStr, "\n"))}
      _ ->
        %{words: Enum.count(String.split(inputStr)),
          lines: Enum.count(String.split(inputStr, "\n"))}
    end
  end
end
