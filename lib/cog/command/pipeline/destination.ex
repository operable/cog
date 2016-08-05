defmodule Cog.Command.Pipeline.Destination do

  @type output_level :: :full | :status_only

  @type t :: %__MODULE__{raw: String.t,
                         output_level: output_level,
                         adapter: String.t,
                         room: term}
  defstruct [raw: nil,
             output_level: :full,
             adapter: nil,
             room: nil]
  use Adz
  alias Cog.Chat.Adapter

  @doc """
  Given a list of raw pipeline destinations, resolve them all to the
  appropriate adapter-specific destinations, or return error tuples
  for each that were invalid.
  """
  def process(raw_destinations, sender, origin_room, origin_adapter) do
    raw_destinations
    |> Enum.map(&make_destination/1)
    |> maybe_add_origin(origin_adapter)
    |> resolve(sender, origin_room, origin_adapter)
  end

  ########################################################################

  defp make_destination(raw),
    do: %__MODULE__{raw: raw}

  # If no destinations are explicitly provided, we return the full
  # output to the same place the request originated from. For chat
  # adapters, this is the same chat room the pipeline was invoked
  # from. For non-chat adapters (e.g., HTTP request), it is the source
  # of the pipeline request (e.g., the HTTP request --- the output
  # will be the body of the HTTP response).
  #
  # If destinations _are_ provided, but the origin is not one of them
  # (denoted by the reserved target "here"), we add a status-only
  # "here" destination, but only if the request came from a non-chat
  # adapter. We do this because, e.g., HTTP requests need a response
  # of some kind, and we want to indicate whether or not the pipeline
  # succeeded.
  #
  # If the origin _is_ one of the destinations, we do nothing special;
  # all explicitly listed destinations receive full output.
  defp maybe_add_origin([], _origin_adapter),
    do: [make_destination("here")]
  defp maybe_add_origin(destinations, origin_adapter) do
    if originator_is_destination?(destinations) || Adapter.is_chat_provider?(origin_adapter) do
      destinations
    else
      [%{make_destination("here") | output_level: :status_only} | destinations]
    end
  end

  defp originator_is_destination?(destinations),
    do: Enum.any?(destinations, &(&1.raw == "here"))

  # Resolve all destinations according to their specified adapter. If
  # all are valid, returns an `{:ok, destinations}` tuple containing
  # all fully-resolved destinations. If any fail to resolve, an
  # `{:error, reasons}` tuple is returned, containing only the errors
  # for the failing destinations.
  defp resolve(destinations, sender, origin_room, origin_adapter) do
    Enum.reduce(destinations, {:ok, []}, fn(destination, {last_status, values}=acc) ->
      {current_status, value} = resolve_destination(destination, sender, origin_room, origin_adapter)
      case {last_status, current_status} do
        {:ok, :ok} -> # Everything is good; collect
          {:ok, [value|values]}
        {:ok, :error} -> # We hit the first error; discard everything before
          {:error, [value]}
        {:error, :error} -> # Still hitting errors; collect
          {:error, [value|values]}
        {:error, :ok} -> # Ignore successful resolutions when we've encountered errors before
          acc
      end
    end)
  end

  defp resolve_destination(%__MODULE__{raw: "here"}=dest, _sender, origin_room, adapter),
    do: {:ok, %{dest | adapter: adapter, room: origin_room}}
  defp resolve_destination(%__MODULE__{raw: "me"}=dest, sender, _origin_room, adapter) do
    user_id = sender["id"]
    case adapter.lookup_direct_room(user_id: user_id) do # TODO: user should be opaque to all but adapter?
      {:ok, direct_chat} ->
        {:ok, %{dest | adapter: adapter.name, room: direct_chat}}
      error ->
        Logger.error("Error resolving redirect 'me' with adapter #{adapter}: #{inspect error}")
        {:error, "me"}
    end
  end
  defp resolve_destination(%__MODULE__{raw: redir}=dest, _sender, _origin_room, origin_adapter) do
    {adapter, destination} = adapter_destination(redir, origin_adapter)
    case adapter.lookup_room(destination) do
      {:ok, room} ->
        if adapter.room_writeable?(id: room.id) == true do # TODO: just pass the room entirely
          {:ok, %{dest | adapter: adapter.name, room: room}}
        else
          {:error, {:not_a_member, redir}}
        end
      {:error, reason} ->
        Logger.error("Error resolving redirect '#{redir}' with adapter #{adapter}: #{inspect reason}")
        {:error, {reason, redir}}
    end
  end

  # Redirect destinations may be targeted to an adapter different from
  # where they originated from.
  #
  # Destinations prefixed with "chat://" will be routed through the
  # active chat adapter module. Anything else will be routed through
  # the adapter that initially serviced the request.
  @spec adapter_destination(String.t, atom) :: {atom, String.t}
  defp adapter_destination("chat://" <> destination, _origin_adapter) do
    {:ok, adapter} = Cog.chat_adapter_module
    {adapter, destination}
  end
  defp adapter_destination(destination, origin_adapter),
    do: {origin_adapter, destination}

end
