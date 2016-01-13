defmodule Cog.Commands.Math do
  @moduledoc """
  This command allows the user to calculate different math functions.
  Currently, the following is supported:
  * add
  * sub
  * multi
  * divide
  * factorial

  Examples:
  > @bot operable:math add 2 2
  > @bot operable:math add 2 24 57 3.7 226.78
  > @bot operable:math sub 7 14
  > @bot operable:math multi 3.14 6
  > @bot operable:math divide 1 6
  > @bot operable:math factorial 59
  """
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  import Cog.Helpers, only: [get_number: 1]

  require Logger

  def handle_message(req, state) do
    [op | remaining] = req.args
    {:reply, req.reply_to, %{result: do_math(op, remaining)}, state}
  end

  defp do_math(operator, nums) do
    exec_operator(operator)
    |> accumulate_args(nums)
  end

  defp exec_operator("add"), do: {0, &(add/2)}
  defp exec_operator("multi"), do: {1, &(multi/2)}
  defp exec_operator("sub"), do: {0, &(sub/2)}
  defp exec_operator("divide"), do: {1, &(divide/2)}
  defp exec_operator("factorial"), do: {1, &(factorial/2)}
  defp exec_operator(unknown), do: {:error, "I don't know how to #{unknown}"}

  defp accumulate_args({:error, err_msg}, _) do
    err_msg
  end
  defp accumulate_args({acc, func}, [first|rest]) do
    num = get_number(first)
    case is_number(num) do
      true -> accumulate_args({func.(num, acc), func}, rest)
      false -> num
    end
  end
  defp accumulate_args({acc, _}, []) do
    Float.to_string(acc/1, [decimals: 4, compact: true])
  end

  defp multi(num, acc) do
    acc * num
  end

  defp add(num, acc) do
    num + acc
  end

  defp sub(num, acc) do
    if acc == 0 do
      num - acc
    else
      acc - num
    end
  end

  def factorial(num, acc) do
    if num == 0 do
      1
    else
      num * factorial(num - 1, acc)
    end
  end

  defp divide(num, acc) do
    if acc == 1 do
      num
    else
      acc / num
    end
  end

end
