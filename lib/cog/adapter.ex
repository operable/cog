defmodule Cog.Adapter do
  @type lookup_result() :: {:ok, String.t} | nil | {:error, any}
  @type lookup_opts() :: [id: String.t] | [name: String.t]

  @callback describe_tree() :: [Supervisor.Spec.spec] | []

  @callback message(room :: String.t, message :: String.t) :: :ok | :error

  @callback lookup_room(lookup_opts()) :: lookup_result()

  @callback lookup_user(lookup_opts()) :: lookup_result()

end
