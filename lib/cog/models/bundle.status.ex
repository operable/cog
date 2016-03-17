defmodule Cog.Models.Bundle.Status do
  # Temporary home of bundle status toggling logic, until such time as
  # the logic on whether or not to dispatch based on bundle status is
  # moved into the executor. Then this module can be simplified / go away / be merged
  # back into `Cog.Models.Bundle`.

  alias Cog.Repo
  alias Cog.Models.Bundle

  @doc """
  Gives the name of the bundle, it's current activation status, and
  a list of relays currently running the bundle (if any).

  Example:

      %{bundle: "github",
        status: "enabled",
        relays: ["44a92066-b1ae-4456-8e6a-4f212bed3180"]}

  """
  def current(bundle) do
    %{bundle: bundle.name,
      relays: Cog.Relay.Relays.relays_running(bundle.name),
      status: bool_to_status(bundle.enabled)}
  end

  @doc """
  Set the status of `bundle`, both in the database, and for any
  currently-running relays.

  Will not operate on the embedded bundle.
  """
  @spec set(%Bundle{}, :enabled | :disabled) :: {:ok, %Bundle{}} | {:error, :embedded_bundle}
  def set(bundle, status) when status in [:enabled, :disabled] do
    if Bundle.embedded?(bundle) do
      {:error, :embedded_bundle}
    else
      bundle = bundle
      |> Bundle.changeset(%{enabled: status_to_bool(status)})
      |> Repo.update!
      {:ok, bundle}
    end
  end

  defp status_to_bool(:enabled), do: true
  defp status_to_bool(:disabled), do: false

  defp bool_to_status(true), do: :enabled
  defp bool_to_status(false), do: :disabled

end
