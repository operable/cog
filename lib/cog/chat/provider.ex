defmodule Cog.Chat.Provider do

  alias Cog.Chat.Room
  alias Cog.Chat.User

  @moduledoc """
  This module describes the mandatory API each chat
  provider module must implement.
  """

  @callback start_link(args :: term) :: {:ok, pid} | {:error, term}

  @callback lookup_user(name :: String.t) :: {:ok, %User{}} | {:error, term}

  @callback list_joined_rooms :: {:ok, [%Room{}] | []} | {:error, term}

  @callback join(room :: String.t) :: :ok | {:error, term}

  @callback leave(room :: String.t) :: :ok | {:error, term}

  @callback send_message(target :: String.t, message :: String.t) :: :ok | {:error, term}

  @callback mention_name(handle :: String.t) :: String.t

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      alias Cog.Chat.Room
      alias Cog.Chat.User

      def lookup_user(_handle), do: {:error, :not_implemented}
      def list_joined_rooms, do: {:error, :not_implemented}
      def join(_room), do: {:error, :not_implemented}
      def leave(_room), do: {:error, :not_implemented}
      def send_message(_target, _message), do: {:error, :not_implemented}

      # TODO: Need to look into how useful this is... the new Slack
      # adapter at least seems to not end up interpreting this as a
      # "mention" when included in output.
      #
      # Perhaps adding this directly into the Cog.Chat.User struct
      # would be useful.
      def mention_name(handle),
        do: "@" <> handle

      defoverridable [lookup_user: 1,
                      list_joined_rooms: 0,
                      join: 1,
                      leave: 1,
                      send_message: 2,
                      mention_name: 1]
    end
  end


end
