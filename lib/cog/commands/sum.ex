defmodule Cog.Commands.Sum do
  @moduledoc """
  This command allows the user to sum together a list of numbers

  Examples:
  > @bot operable:sum 2 2
  > @bot operable:sum 2 "-9"
  > @bot operable:sum 2 24 57 3.7 226.78
  """
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  require Logger
  import Cog.Helpers, only: [get_number: 1]

  def handle_message(req, state) do
    {:reply, req.reply_to, %{sum: sum_list(req.args)}, state}
  end

  defp sum_list(nums) do
    accumulate_args(nums, 0)
  end

  defp accumulate_args([], acc) do
    Float.to_string(acc/1, [decimals: 8, compact: true])
  end
  defp accumulate_args([first|rest], acc) do
    num = get_number(first)
    case is_number(num) do
      true -> accumulate_args(rest, num + acc)
      false -> num
    end
  end
end
