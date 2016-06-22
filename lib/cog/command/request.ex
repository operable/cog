defmodule Cog.Command.Request do

  use Cog.Marshalled

  require Logger

  # defmarshalled [:room, :requestor, :user, :command, :args, :options,
  #                :command_config, :reply_to, :cog_env, :invocation_id,
  #                :invocation_step, :service_token, :services_root]

  defmarshalled [:options, :args, :cog_env, :invocation_step]

  defp validate(request) do
    cond do
      request.invocation_step == nil ->
        {:error, {:empty_field, :invocation_step}}
      request.cog_env == nil ->
        {:error, {:empty_field, :cog_env}}
    end
  end

end
