defmodule Carrier.SecurityError do
  @moduledoc """
Used to signal security errors such as incorrect file permissions on public
or private keys.
  """
  defexception [:message]

  def new(message) do
    %__MODULE__{message: message}
  end

  def wrong_permission(path, expected, found) do
    "#{path} should have mode #{Integer.to_string(expected, 8)} " <>
      "but has #{Integer.to_string(found, 8)}"
  end

end
