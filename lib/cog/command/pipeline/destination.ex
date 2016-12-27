defmodule Cog.Command.Pipeline.Destination do

  @type classification :: :chat | :trigger | :status_only
  @type t :: %__MODULE__{raw: String.t,
                         adapter: String.t,
                         room: %CogChat.Room{},
                         classification: classification}
  defstruct [raw: nil,
             adapter: nil,
             room: nil,
             classification: nil]

  require Logger
  alias CogChat.Adapter

  @doc """
  Given a list of raw pipeline destinations, resolve them all to the
  appropriate adapter-specific destinations, grouped by their output
  disposition classification, or return error tuples for each that
  were invalid.
  """
  def process(raw_destinations, sender, origin_room, origin_adapter) when is_binary(origin_adapter) do
    result = raw_destinations
    |> Enum.map(&make_destination/1)
    |> maybe_add_origin(origin_adapter)
    |> resolve(sender, origin_room, origin_adapter)

    case result do
      {:ok, destinations} ->
        {:ok, Enum.group_by(destinations, &(&1.classification))}
      {:error, _}=error ->
        error
    end
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
      [%{make_destination("here") | classification: :status_only} | destinations]
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

  defp resolve_destination(%__MODULE__{raw: "here"}=dest, _sender, origin_room, adapter) do
    # If we had to add a "here" destination, it'll already have been
    # classified; we need to respect that
    {:ok, %{dest | adapter: adapter, room: origin_room,
            classification: Map.get(dest, :classification) || classify_adapter(adapter)}}
  end
  defp resolve_destination(%__MODULE__{raw: "me"}=dest, sender, _origin_room, adapter) do
    # TODO: handle the pathological case of the sender ID not actually
    # resolving to a destination... also need to handle the case where
    # "me" isn't a recognized destination (e.g., for HTTP adapter)
    {:ok, room} = Adapter.lookup_room(adapter, id: sender.id)
    {:ok, %{dest | adapter: adapter, room: room, classification: classify_adapter(adapter)}}
  end
  defp resolve_destination(%__MODULE__{raw: redir}=dest, _sender, _origin_room, origin_adapter) do
    {adapter, destination} = adapter_destination(redir, origin_adapter)
    case Adapter.lookup_room(adapter, name: destination) do
      {:error, reason} ->
        {:error, {reason, redir}}
      {:ok, room} ->
        {:ok, %{dest | adapter: adapter, room: room, classification: classify_adapter(adapter)}}
    end
  end

  # Redirect destinations may be targeted to an adapter different from
  # where they originated from.
  #
  # Destinations prefixed with "chat://" will be routed through the
  # active chat adapter module. Anything else will be routed through
  # the adapter that initially serviced the request.
  @spec adapter_destination(String.t, String.t) :: {String.t, String.t}
  defp adapter_destination("chat://" <> destination, _origin_adapter) do
    {:ok, adapter} = Cog.Util.Misc.chat_adapter_module
    {adapter, destination}
  end
  defp adapter_destination(destination, origin_adapter),
    do: {origin_adapter, destination}


  # TODO: perhaps let Adapter handle this logic instead
  defp classify_adapter(adapter) do
    if Adapter.is_chat_provider?(adapter) do
      :chat
    else
      :trigger
    end
  end

end
