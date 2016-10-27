defmodule Cog.Commands.Tee do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  require Logger

  alias Cog.Command.Service.MemoryClient
  alias Cog.Command.Service.DataStore

  @data_namespace [ "commands", "tee" ]

  @description "Save and pass through pipeline data"

  @long_description """
  The tee command passes the output of a Cog pipeline through to the next command in the pipeline while also saving it using the provided name. The saved output can be retreived later using the cat command.

  If the name of a previously saved object is reused, tee will overwrite the existing data. There is not currently a way to delete saved content from Cog, but you can simulate this behavior by sending a replacement object to tee again with the name of the object you wish to delete.

  Think carefully about the type of data that you store using tee since it will be retrievable by default by any Cog user. Careful use of rules and naming conventions could be used to limit access, though keep in mind that a simple typo in naming could cause unexpected data to be accessible. For example, the rules below would require you to have the "site:prod-data" permission in order to save or retrieve objects whose names begin with "prod-".

  operable:rule create "when command is operable:tee with arg[0] == /^prod-.*/ must have site:prod-data"
  operable:rule create "when command is operable:cat with arg[0] == /^prod-.*/ must have site:prod-data"
  """

  @arguments "<name>"

  @examples """
  seed '{ "thing": "stuff" }' | tee foo
  > '{ "thing": "stuff" }'
  cat foo
  > '{ "thing": "stuff" }'
  """

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:tee allow"

  def handle_message(%{args: [key]} = req, state) do
    root = req.services_root
    token = req.service_token
    step = req.invocation_step
    value = req.cog_env
    memory_key = req.invocation_id

    MemoryClient.accum(root, token, memory_key, value)

    case step do
      step when step in ["first", nil] ->
        {:reply, req.reply_to, nil, state}
      "last"->
        data =
          MemoryClient.fetch(root, token, memory_key)
          |> Enum.reject(fn(value) -> value == %{} end)
          |> maybe_unwrap

        MemoryClient.delete(root, token, memory_key)

        case DataStore.replace(@data_namespace, key, data) do
          {:error, reason} ->
            {:error, req.reply_to, "Unable to store pipeline content: #{inspect reason}"}
          {:ok, _} ->
            {:reply, req.reply_to, data, state}
        end
    end
  end

  def handle_message(%{args: []} = req, state) do
    {:error, req.reply_to, "#{Cog.Util.Misc.embedded_bundle}:tee requires a name to be specified for the pipeline content", state}
  end

  defp maybe_unwrap([data]), do: data
  defp maybe_unwrap(data),   do: data
end
