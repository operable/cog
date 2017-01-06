defmodule Cog.Command.Pipeline.Destination do

  @type classification :: :chat | :trigger | :status_only
  @type t :: %__MODULE__{raw: String.t,
                         provider: String.t,
                         room: %Cog.Chat.Room{},
                         classification: classification}
  defstruct [raw: nil,
             provider: nil,
             room: nil,
             classification: nil]

  require Logger
  alias Cog.Chat.Adapter, as: ChatAdapter

  @doc """
  Given a list of raw pipeline destinations, resolve them all to the
  appropriate provider-specific destinations, grouped by their output
  disposition classification, or return error tuples for each that
  were invalid.
  """
  def process(raw_destinations, sender, origin_room, origin_provider) when is_binary(origin_provider) do
    result = raw_destinations
    |> Enum.map(&make_destination/1)
    |> maybe_add_origin(origin_provider)
    |> resolve(sender, origin_room, origin_provider)

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
  # providers, this is the same chat room the pipeline was invoked
  # from. For non-chat providers (e.g., HTTP request), it is the source
  # of the pipeline request (e.g., the HTTP request --- the output
  # will be the body of the HTTP response).
  #
  # If destinations _are_ provided, but the origin is not one of them
  # (denoted by the reserved target "here"), we add a status-only
  # "here" destination, but only if the request came from a non-chat
  # provider. We do this because, e.g., HTTP requests need a response
  # of some kind, and we want to indicate whether or not the pipeline
  # succeeded.
  #
  # If the origin _is_ one of the destinations, we do nothing special;
  # all explicitly listed destinations receive full output.
  defp maybe_add_origin([], _origin_provider),
    do: [make_destination("here")]
  defp maybe_add_origin(destinations, origin_provider) do
    if originator_is_destination?(destinations) || ChatAdapter.is_chat_provider?(origin_provider) do
      destinations
    else
      [%{make_destination("here") | classification: :status_only} | destinations]
    end
  end

  defp originator_is_destination?(destinations),
    do: Enum.any?(destinations, &(&1.raw == "here"))

  # Resolve all destinations according to their specified provider. If
  # all are valid, returns an `{:ok, destinations}` tuple containing
  # all fully-resolved destinations. If any fail to resolve, an
  # `{:error, reasons}` tuple is returned, containing only the errors
  # for the failing destinations.
  defp resolve(destinations, sender, origin_room, origin_provider) do
    Enum.reduce(destinations, {:ok, []}, fn(destination, {last_status, values}=acc) ->
      {current_status, value} = resolve_destination(destination, sender, origin_room, origin_provider)
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

  defp resolve_destination(%__MODULE__{raw: "here"}=dest, _sender, origin_room, provider) do
    # If we had to add a "here" destination, it'll already have been
    # classified; we need to respect that
    {:ok, %{dest | provider: provider, room: origin_room,
            classification: Map.get(dest, :classification) || classify_provider(provider)}}
  end
  defp resolve_destination(%__MODULE__{raw: "me"}=dest, sender, _origin_room, provider) do
    # TODO: handle the pathological case of the sender ID not actually
    # resolving to a destination... also need to handle the case where
    # "me" isn't a recognized destination (e.g., for HTTP provider)
    {:ok, room} = ChatAdapter.lookup_room(provider, id: sender.id)
    {:ok, %{dest | provider: provider, room: room, classification: classify_provider(provider)}}
  end
  defp resolve_destination(%__MODULE__{raw: redir}=dest, _sender, _origin_room, origin_provider) do
    {provider, destination} = provider_destination(redir, origin_provider)
    case ChatAdapter.lookup_room(provider, name: destination) do
      {:error, reason} ->
        {:error, {reason, redir}}
      {:ok, room} ->
        {:ok, %{dest | provider: provider, room: room, classification: classify_provider(provider)}}
    end
  end

  # Redirect destinations may be targeted to an provider different from
  # where they originated from.
  #
  # Destinations prefixed with "chat://" will be routed through the
  # active chat provider module. Anything else will be routed through
  # the provider that initially serviced the request.
  @spec provider_destination(String.t, String.t) :: {String.t, String.t}
  defp provider_destination("chat://" <> destination, _origin_provider) do
    {:ok, provider} = Cog.Util.Misc.chat_provider_module
    {provider, destination}
  end
  defp provider_destination(destination, origin_provider),
    do: {origin_provider, destination}


  # TODO: perhaps let Provider handle this logic instead
  defp classify_provider(provider) do
    if ChatAdapter.is_chat_provider?(provider) do
      :chat
    else
      :trigger
    end
  end

end
