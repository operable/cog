defmodule Cog.Command.Request do

  use Cog.Marshalled

  require Logger

  defmarshalled [:options, :args, :cog_env, :invocation_step]

  defp validate(request) do
    case do
      request.invocation_step == nil ->
        {:error, {:empty_field, :invocation_step}}
      request.cog_env == nil ->
        {:error, {:empty_field, :cog_env}}
      true ->
        request
    end
  end

end
