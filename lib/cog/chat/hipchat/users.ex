defmodule Cog.Chat.HipChat.Users do

  require Logger

  alias Romeo.Roster
  alias Cog.Chat.HipChat.Util

  defstruct [users: %{}, last_updated: 0]

  @roster_refresh_interval 120000

  def lookup(%__MODULE__{}=users, xmpp_conn, jid: jid) do
    find_user(users, xmpp_conn, jid)
  end
  def lookup(%__MODULE__{}=users, xmpp_conn, handle: handle) do
    find_user(users, xmpp_conn, handle)
  end
  def lookup(_users, _conn, args) do
    raise RuntimeError, message: "Unknown arg: #{inspect args}"
  end

  defp find_user(users, xmpp_conn, handle_or_id) do
    case Map.get(users.users, handle_or_id) do
      nil ->
        case rebuild_users(users, xmpp_conn) do
          {:ok, users} ->
            {Map.get(users.users, handle_or_id), users}
          error ->
            error
        end
      user ->
        {user, users}
    end
  end

  defp rebuild_users(%__MODULE__{}=users, xmpp_conn) do
    ri = System.system_time() - users.last_updated
    if ri > @roster_refresh_interval do
      try do
        roster = Enum.reduce(Roster.items(xmpp_conn), %{},
          fn(item, roster) ->
            entry = Util.user_from_roster(item, "hipchat")
            roster = if entry.handle != "" do
              Map.put(roster, entry.handle, entry)
            else
              roster
            end
            roster = if entry.mention_name != "" do
              Map.put(roster, entry.mention_name, entry)
            else
              roster
            end

            roster
            |> Map.put("#{entry.first_name} #{entry.last_name}", entry)
            |> Map.put(entry.id, entry)
          end)
        {:ok, %{users | users: roster, last_updated: System.system_time()}}
      catch
        e ->
        Logger.error("Refreshing HipChat roster failed: #{inspect e}")
        {:error, :roster_failed}
      end
    else
      {:ok, users}
    end
  end

end
