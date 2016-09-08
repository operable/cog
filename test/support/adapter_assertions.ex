defmodule Cog.AdapterAssertions do
  import ExUnit.Assertions

  @doc """
  Compare a fragment of an error message from a chat adapter to the
  complete textual response given.
  """
  def assert_error_message_contains(actual_response, expected_message_fragment) do
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
