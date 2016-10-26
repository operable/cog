defmodule Cog.Commands.Cat do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Command.Service.DataStore

  # Note, we use the `tee` namespace because the namespace we read from
  # must be the same one that data was written into.
  @data_namespace [ "commands", "tee" ]

  @description "Retrieve saved pipeline output"

  @long_description """
  The cat command retrieves pipeline output that was previously saved using the tee command.
  """

  @arguments "<name>"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:cat allow"

  option "merge", short: "m", type: "bool", required: false,
         description: "Merge current pipeline map into saved pipeline map"

  option "append", short: "a", type: "bool", required: false,
         description: "Append current pipeline output to saved pipeline data, returning an array"

  option "insert", short: "i", type: "string", required: false,
         description: "Insert current pipeline output into saved pipeline map as the field specified for this option"

  def handle_message(%{options: %{"merge" => true, "append" => true}} = req, state) do
    {:error, req.reply_to, "The append and merge options cannot be specified together", state}
  end

  def handle_message(%{args: [key], options: opts} = req, state) do
    case DataStore.fetch(@data_namespace, key) do
      {:ok, data} ->
        cond do
          opts["insert"] ->
            handle_transform(:insert, req, data, state)
          opts["append"] ->
            {:reply, req.reply_to, List.wrap(data) ++ List.wrap(req.cog_env), state}
          opts["merge"] ->
            handle_transform(:merge, req, data, state)
          true ->
            {:reply, req.reply_to, data, state}
        end
      {:error, reason} ->
        {:error, req.reply_to, "Unable to retrieve data for #{key}: #{inspect reason}", state}
    end
  end

  def handle_message(%{args: []} = req, state),
    do: {:error, req.reply_to, "#{Cog.Util.Misc.embedded_bundle}:cat requires a name to be specified", state}

  defp handle_transform(action, req, data, state) do
    case transform_map_data(action, req.cog_env, data, req.options) do
      {:ok, result} ->
        {:reply, req.reply_to, result, state}
      {:error, reason} ->
        {:error, req.reply_to, reason, state}
    end
  end

  defp transform_map_data(action, [prev], curr, opts),
    do: transform_map_data(action, prev, curr, opts)
  defp transform_map_data(action, prev, [curr], opts),
    do: transform_map_data(action, prev, curr, opts)
  defp transform_map_data(:merge, prev, curr, _opts) when is_map(prev) and is_map(curr) do
    {:ok, Map.merge(prev, curr)}
  end
  defp transform_map_data(:insert, prev, curr, opts) when is_map(prev) and is_map(curr) do
    {:ok, Map.put(prev, opts["insert"], curr)}
  end
  defp transform_map_data(action, _prev, _curr, _opts) do
    {:error, "The #{Atom.to_string(action)} option is only applicable for map values"}
  end
end
