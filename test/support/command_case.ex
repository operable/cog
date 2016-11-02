defmodule Cog.CommandCase do

  @moduledoc """
  Test case for internal Cog commands
  """

  use ExUnit.CaseTemplate

  using command_module: command_module do
    quote do
      alias Cog.Support.ModelUtilities
      alias unquote(command_module)

      @command_name Module.split(unquote(command_module)) |> List.last |> String.downcase

      defp new_req(opts \\ []) do
        %Cog.Messages.Command{invocation_id: Keyword.get(opts, :invocation_id, "fake_invocation_id"),
                              command: Keyword.get(opts, :command, @command_name),
                              args: Keyword.get(opts, :args, []),
                              options: Keyword.get(opts, :options, %{}),
                              cog_env: Keyword.get(opts, :cog_env, %{}),
                              invocation_step: Keyword.get(opts, :invocation_step, "last"),
                              reply_to: Keyword.get(opts, :reply_to, "fake_reply_to"),
                              requestor: Keyword.get(opts, :requestor, %Cog.Chat.User{}),
                              room: Keyword.get(opts, :room, %Cog.Chat.Room{}),
                              service_token: Keyword.get(opts, :service_token, "fake_service_token"),
                              services_root: Keyword.get(opts, :services_root, "fake_services_root"),
                              user: Keyword.get(opts, :user, %{})}
      end

      defp send_req(module \\ unquote(command_module), %Cog.Messages.Command{}=req) do
        case module.handle_message(req, %{}) do
          {:reply, _reply_to, _template, reply, _state} ->
            {:ok, Poison.encode!(reply)}
          {:reply, _reply_to, reply, _state} ->
            {:ok, Poison.encode!(reply)}
          {:error, _reply_to, error_message, _state} ->
            {:error, error_message}
        end
      end

    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    :ok
  end
end
