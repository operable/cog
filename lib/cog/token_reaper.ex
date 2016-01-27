defmodule Cog.TokenReaper do
  @moduledoc """
  Worker for periodic removal of expired tokens from the database.

  As tokens expire and are no longer being used, they must be removed
  from the database, or else the token table will fill with useless
  data. This GenServer sleeps in the background, periodically waking
  up to delete any tokens that have expired since the last reaping.
  """

  use GenServer
  require Logger
  alias Cog.Config

  defstruct period: nil, # integer; milliseconds
            ttl: nil     # integer; seconds

  # TODO: Info tracking
  #       Last reaped at XXX; deleted XXX tokens
  # TODO: Explicit `reap` function that can be called interactively
  #       (would need to track and manage timer references, though)

  @doc """
  Start registered reaper process, taking configuration from
  `:token_lifetime` and `:token_reap_period` configuration of the
  `:cog` application.
  """
  def start_link do
    ttl = Config.token_lifetime
    period = Config.token_reap_period

    GenServer.start_link(__MODULE__, [period, ttl], name: __MODULE__)
  end

  @doc """
  Arguments:

  - period: the amount of time between successive reap operations, in
    milliseconds
  - ttl: the age at which a token is considered expired, in seconds
  """
  def init([period, ttl]) do
    schedule_next_reaping(1000)
    {:ok, %__MODULE__{period: period,
                      ttl: ttl}}
  end

  def handle_info(:reap, state) do
    :ok = delete_expired_tokens(state.ttl)
    schedule_next_reaping(state.period)
    {:noreply, state, :hibernate}
  end

  defp schedule_next_reaping(period) do
    Logger.info ("Scheduling next expired token reaping for approximately #{ms_to_hours(period)} hours from now")
    :erlang.send_after(period, self(), :reap)
  end

  defp delete_expired_tokens(ttl) do
    {num, nil} = ttl
    |> Cog.Queries.Token.expired
    |> Cog.Repo.delete_all

    case num do
      0 -> Logger.info("No expired tokens to delete")
      _ -> Logger.info("Deleted #{num} expired tokens")
    end
    :ok
  end

  # Make the logging messages a little easier to read. If reapings run
  # on the order of days or weeks apart, seeing millions of
  # milliseconds is not only confusing, but speaks to a level of
  # accuracy that we can't really provide.
  #
  # Returns an integer number of hours.
  defp ms_to_hours(ms) do
    ms / 1000 / 60 / 60 |> Float.floor |> trunc
  end
end
