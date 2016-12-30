defmodule Cog.CommandCase do

  @moduledoc """
  Test case for internal Cog commands
  """

  use ExUnit.CaseTemplate, async: true

  using opts do
    quote location: :keep, bind_quoted: [opts: opts] do
      import Cog.CommandCase
      import Cog.Test.Util

      # command_module and command_tag provide some niceties and shortcuts
      # for working with command tests. Both are optional.

      # command_module: The default command module to send requests to.
      # Specifying this will also add a @moduletag in the form of
      # 'commands: <command_name>' where command_name is the last word in the
      # module downcased. For example 'Cog.Commands.Help' would generate
      # '@moduletag commands: "help"'. If command_module isn't specified you
      # will need to explicitly pass the command module when calling send_req/2.

      # command_tag: The command_name used for the generated @moduletag.
      # @moduletag is generated in the form 'commands: <command_name>'. If
      # both command_module and command_tag are specified, command_tag will
      # take precedence over the value extracted from the command module.


      # If defined we'll use the command_module later to generate send_req/1,
      # so we'll go ahead and assign it here.
      command_module = Keyword.get(opts, :command_module)

      # Sets up the @moduletag
      # If neither command_module or command_tag are set the @moduletag is set
      # to 'commands: true'. So even though you can't specify the specific
      # command test to run, you can still run the test when all command tests
      # are ran.
      moduletag = cond do
        command_tag = Keyword.get(opts, :command_tag) ->
          command_tag
        command_module ->
          command_name = Module.split(command_module)
          |> List.last()
          |> String.downcase()

          command_name
        true ->
          true
      end

      @moduletag commands: moduletag

      # If the command_module is set then we can provide a convenience function
      # with the command_module already filled in. This should help reduce some
      # of the repetition.
      if command_module do
        @command_module command_module

        def send_req(req),
          do: send_req(req, @command_module)
      end

    end
  end

  setup do
    # We manually checkout the DB connection each time.
    # This allows us to run tests async.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Cog.Repo)
    :ok
  end

  def new_req(opts \\ []) do
    %Cog.Messages.Command{
      invocation_id: Keyword.get(opts, :invocation_id, "fake_invocation_id"),
      command: Keyword.get(opts, :command),
      args: Keyword.get(opts, :args, []),
      options: Keyword.get(opts, :options, %{}),
      cog_env: Keyword.get(opts, :cog_env, %{}),
      invocation_step: Keyword.get(opts, :invocation_step, "last"),
      reply_to: Keyword.get(opts, :reply_to, "fake_reply_to"),
      requestor: Keyword.get(opts, :requestor, %Cog.Chat.User{provider: "test"}),
      room: Keyword.get(opts, :room, %Cog.Chat.Room{}),
      service_token: Keyword.get(opts, :service_token, service_token()),
      services_root: Keyword.get(opts, :services_root, services_root()),
      user: Keyword.get(opts, :user, %{})}
  end

  def send_req(%Cog.Messages.Command{}=req, module) do
    case module.handle_message(req, %{}) do
      {:reply, _reply_to, _template, nil, _state} ->
        {:ok, nil}
      {:reply, _reply_to, nil, _state} ->
        {:ok, nil}
      {:reply, _reply_to, _template, reply, _state} ->
        # We're encoding and then decoding here because that's basically what happens
        # normally when the message is sent over the bus. For our use case this strips
        # a lot of the cruft from the normal return value, simulating what happens to
        # the data as it goes through a normal pipeline.
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

  def memory_accum(root \\ services_root(), token \\ service_token(), key, value),
    do: Cog.Command.Service.MemoryClient.accum(root, token, key, value)

  def memory_fetch(root \\ services_root(), token \\ service_token(), key),
    do: Cog.Command.Service.MemoryClient.fetch(root, token, key)

  # The service token is unique per process, so we create one with the first `new_req`
  # and store that in the process dictionary for any additional reqs.
  def service_token do
    case Process.get(:service_token) do
      nil ->
        token = Cog.Command.Service.Tokens.new()
        Process.put(:service_token, token)
        token
      token ->
        token
    end
  end

  def services_root,
    do: Cog.ServiceEndpoint.url()
end
