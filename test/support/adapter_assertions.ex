defmodule Cog.AdapterAssertions do
  import ExUnit.Assertions

  def assert_message(%{"response" => response}, expected_message) do
    assert response == expected_message
  end

  # Because the raw template returns encoded json joined by newlines we have to
  # add in newlines and then pull out the single result or return a list of
  # result for those cases.
  def assert_payload(response, expected_payload) do
    payload = case decode_payload(response) do
      [payload] ->
        payload
      payload ->
        payload
    end

    assert payload == expected_payload
  end

  def decode_payload(%{"response" => response}) do
    decode_payload(response)
  end
  def decode_payload([string]) when is_binary(string) do
    decode_payload(string)
  end
  def decode_payload([map]) when is_map(map) do
    [map]
  end
  def decode_payload(response) do
    response = response
    |> String.replace(~r/^}/m, "},")
    |> String.rstrip(?,)

    case Poison.decode("[#{response}]", keys: :atoms) do
      {:ok, decoded} ->
        decoded
      {:error, _} ->
        # This makes for easier test debugging
        raise "Expected JSON, got: #{inspect response}"
    end
  end

  @doc """
  Temporary helper assertion to compare a fragment of an error message
  from a chat adapter to the complete textual response given.

  Eventually, we'll move to error templates, which actually will allow
  us to compare to a data structure instead of a string, and will
  allow these tests to be more robust.
  """

  def assert_error_message_contains(%{error: actual_response}, expected_message_fragment) do
    assert_error_message_contains(actual_response, expected_message_fragment)
  end
  def assert_error_message_contains(%{"response" => actual_response}, expected_message_fragment) do
    assert_error_message_contains(actual_response, expected_message_fragment)
  end
  def assert_error_message_contains([actual_response], expected_message_fragment) when is_binary(actual_response) do
    assert_error_message_contains(actual_response, expected_message_fragment)
  end
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
