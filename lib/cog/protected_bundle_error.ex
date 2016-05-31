defmodule Cog.ProtectedBundleError do
  defexception [:message, :bundle]

  def exception(bundle_name),
    do: %__MODULE__{message: "Operation not permitted on a protected bundle #{inspect bundle_name}",
                    bundle: bundle_name}

end
