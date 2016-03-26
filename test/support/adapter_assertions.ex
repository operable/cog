defmodule Cog.AdapterAssertions do
  import ExUnit.Assertions

  def assert_message(%{"response" => response}, expected_message) do
    assert response == expected_message
  end

  @doc """
  Temporary helper assertion to compare a fragment of an error message
  from a chat adapter to the complete textual response given.

  Eventually, we'll move to error templates, which actually will allow
  us to compare to a data structure instead of a string, and will
  allow these tests to be more robust.
  """
  def assert_error_message_contains(%{"response" => actual_response}, expected_message_fragment) do
    if String.contains?(actual_response, expected_message_fragment) do
      :ok
    else
      flunk """

      Expected the string

          #{inspect actual_response}

      to contain the string

          #{inspect expected_message_fragment}

      but it didn't!
      """
    end
  end

end
