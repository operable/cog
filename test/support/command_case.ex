defmodule Cog.CommandCase do

  @moduledoc """
  Test case for internal Cog commands
  """

  use ExUnit.CaseTemplate, async: true

  using opts do
    quote location: :keep do
      import unquote(__MODULE__)

      @command_module Keyword.fetch!(unquote(opts), :command_module)
      @command_name Module.split(@command_module) |> List.last |> String.downcase

      @moduletag commands: @command_name

      # So we don't have to keep passing the command name and command module
      def send_req(req),
        do: send_req(@command_module, req)

      def new_req(opts \\ []),
        do: new_req(@command_name, opts)
    end
  end

  setup do
    # We manually checkout the DB connection each time.
    # This allows us to run tests async.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    :ok
  end

  def new_req(command, opts) do
    %Cog.Messages.Command{
      invocation_id: Keyword.get(opts, :invocation_id, "fake_invocation_id"),
      command: Keyword.get(opts, :command, command),
      args: Keyword.get(opts, :args, []),
      options: Keyword.get(opts, :options, %{}),
      cog_env: Keyword.get(opts, :cog_env, %{}),
      invocation_step: Keyword.get(opts, :invocation_step, "last"),
      reply_to: Keyword.get(opts, :reply_to, "fake_reply_to"),
      requestor: Keyword.get(opts, :requestor, %Cog.Chat.User{}),
      room: Keyword.get(opts, :room, %Cog.Chat.Room{}),
      service_token: Keyword.get(opts, :service_token, service_token()),
      services_root: Keyword.get(opts, :services_root, Cog.ServiceEndpoint.public_url()),
      user: Keyword.get(opts, :user, %{})}
  end

  def send_req(module, %Cog.Messages.Command{}=req) do
    case module.handle_message(req, %{}) do
      {:reply, _reply_to, _template, nil, _state} ->
        {:ok, nil}
      {:reply, _reply_to, nil, _state} ->
        {:ok, nil}
      {:reply, _reply_to, _template, reply, _state} ->
        # We're encoding and then decoding here because that's basically what happens
        # normally when the message is sent over the bus. It also serves to strip a
        # lot of the cruft from the reply and makes it more closely resemble what it
        # would normally.
        reply = Poison.encode!(reply)
        |> Poison.decode!(keys: :atoms)
        {:ok, reply}
      {:reply, _reply_to, reply, _state} ->
        reply = Poison.encode!(reply)
        |> Poison.decode!(keys: :atoms)
        {:ok, reply}
      {:error, _reply_to, error_message, _state} ->
        {:error, error_message}
    end
  end
  # If we get a list of reqs then we set the invocation_step for each and map over them
  def send_req(module, reqs) when is_list(reqs) do
    Enum.map(reqs, &(%{&1 | invocation_step: nil}))
    |> List.update_at(0, &(%{&1 | invocation_step: "first"}))
    |> List.update_at(-1, &(%{&1 | invocation_step: "last"}))
    |> Enum.map(&(send_req(module, &1)))
  end

  # Service token is unique per process, so we create one with the first `new_req`
  # and store that in the process dictionary for any additional reqs
  defp service_token do
    case Process.get(:service_token) do
      nil ->
        token = Cog.Command.Service.Tokens.new()
        Process.put(:service_token, token)
        token
      token ->
        token
    end
  end

end
