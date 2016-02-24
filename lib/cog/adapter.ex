defmodule Cog.Adapter do
  @type lookup_result() :: {:ok, String.t} | nil | {:error, any}
  @type lookup_opts() :: [id: String.t] | [name: String.t]

  @callback describe_tree() :: [Supervisor.Spec.spec] | []

  @callback send_message(room :: String.t, message :: String.t) :: :ok | :error

  @callback lookup_room(lookup_opts()) :: lookup_result()

  @callback lookup_direct_room(lookup_opts()) :: lookup_result()

  @callback service_name() :: String.t

  @callback bus_name() :: String.t

  @callback mention_name(String.t) :: String.t
end
