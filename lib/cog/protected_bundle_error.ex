defmodule Cog.ProtectedBundleError do
  defexception [:message, :reason]

  def exception(reason),
    do: %__MODULE__{message: "Operation not permitted on a protected bundle: #{inspect reason}",
                    reason: reason}

end
