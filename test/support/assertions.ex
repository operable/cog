defmodule Cog.Assertions do
  import ExUnit.Assertions
  alias Cog.Time
  require Logger

  @interval 1000 #  1 second
  @timeout 10000 # 10 seconds

  # Used when the expected and actual values will eventually converge within a
  # given timeout. The `expected` value will be checked for equality with the
  # result from running `actual_func`. If the two values are not equal the
  # process will sleep for `interval` and then try again until either
  # succeeding or timing out after `timeout`.
  def polling_assert(expected, actual_func, interval \\ @interval, timeout \\ @timeout) do
    try_until = Time.now + (timeout / 1000)
    do_polling_assert(expected, actual_func, try_until, interval)
  end

  def polling_assert_in(expected, actual_func, interval \\ @interval, timeout \\ @timeout) do
    try_until = Time.now + (timeout / 1000)
    do_polling_assert_in(expected, actual_func, try_until, interval)
  end

  def polling(actual_func, interval \\ @interval, timeout \\ @timeout) do
    try_until = Time.now + (timeout / 1000)
    do_polling(actual_func, try_until, interval)
  end

  defp do_polling(actual_func, try_until, interval) do
    if try_until > Time.now do
      case actual_func.() do
        nil ->
          Logger.debug("Didn't receive a new message. Trying again...")
          :timer.sleep(interval)
          do_polling(actual_func, try_until, interval)
        actual ->
          actual
      end
    else
      adapter = Application.get_env(:cog, :adapter)
      raise "Timed out waiting to receive a new message using adapter #{inspect adapter}"
    end
  end

  defp do_polling_assert(expected, actual_func, try_until, interval) do
    if try_until > Time.now do
      case actual_func.() do
        nil ->
          Logger.debug("Didn't receive a new message. Trying again...")
          :timer.sleep(interval)
          do_polling_assert(expected, actual_func, try_until, interval)
        actual ->
          assert expected == actual
      end
    else
      adapter = Application.get_env(:cog, :adapter)
      raise "Timed out waiting to receive a new message using adapter #{inspect adapter}"
    end
  end

  defp do_polling_assert_in(expected, actual_func, try_until, interval) do
    if try_until > Time.now do
      case actual_func.() do
        nil ->
          Logger.debug("Didn't receive a new message. Trying again...")
          :timer.sleep(interval)
          do_polling_assert_in(expected, actual_func, try_until, interval)
        actual ->
          String.contains?(actual, expected)
      end
    else
      adapter = Application.get_env(:cog, :adapter)
      raise "Timed out waiting to receive a new message using adapter #{inspect adapter}"
    end
  end

end
