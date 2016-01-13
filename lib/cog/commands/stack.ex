defmodule Cog.Commands.Stack do
  use Spanner.GenCommand.Base, bundle: Cog.embedded_bundle, enforcing: false
  defstruct [:store]

  @moduledoc """
  A simple stack.
  usage: stack [--key][--flush|--pop][--size] <values>

  ## Options

      --flush  Flushes the stack
      --pop    Pops the last value off the stack
      --size   Returns the current size of the stack
      --key    Optionally send a key to store your stack in (default is your user id)


  ## Example

      @bot operable:stack one two three
      > Stack size: 3
      @bot operable:stack --pop
      > three
  """

  option "flush", type: "bool", required: false
  option "pop", type: "bool", required: false
  option "size", type: "bool", required: false
  option "key", type: "string", required: false

  def init(_) do
    {:ok, %__MODULE__{store: []}}
  end

  def handle_message(req, state) do
    {response, new_state} = process(req.options, req, state)
    {:reply, req.reply_to, response, new_state}
  end

  defp process(%{"size" => true}, req, state) do
    id = get_id(req)

    case List.keyfind(state.store, id, 0) do
      {_key, values} ->
        {"Stack size: #{length(values)}", state}
      nil ->
        {"You have nothing on the stack", state}
    end
  end
  defp process(%{"pop" => true}, req, state) do
    id = get_id(req)

    case List.keytake(state.store, id, 0) do
      {{key, [value|rest]}, new_store} ->
        {value, %__MODULE__{state | store: [{key, rest}] ++ new_store}}
      nil ->
        {"Sorry I didn't find anything for you @#{req.requestor["handle"]}.", state}
    end
  end
  defp process(%{"flush" => true}, req, state) do
    id = get_id(req)

    case List.keytake(state.store, id, 0) do
      {{_key, values}, new_store} ->
        {%{values: List.flatten(req.args ++ values)}, %__MODULE__{store: new_store}}
      nil ->
        {"Sorry I didn't find anything for you @#{req.requestor["handle"]}.", state}
    end
  end
  defp process(%{}, req, state) do
    id = get_id(req)
    args = Enum.reverse(req.args)

    case List.keytake(state.store, id, 0) do
      {{key, values}, new_store} ->
        {"Stack size: #{length(values) + length(args)}", %__MODULE__{state | store: [{key, req.args ++ values}] ++ new_store}}
      nil ->
        {"Stack size: #{length(args)}", %__MODULE__{state | store: [{id, args}] ++ state.store}}
    end
  end

  defp get_id(%Spanner.Command.Request{options: %{"key" => key}}), do: key
  defp get_id(%Spanner.Command.Request{requestor: %{"id" => id}}), do: id
end
