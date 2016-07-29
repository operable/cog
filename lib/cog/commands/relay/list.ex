defmodule Cog.Commands.Relay.List do
  alias Cog.Commands.Helpers
  alias Cog.Repository.Relays

  alias Cog.Commands.Relay.ViewHelpers

  @moduledoc """
  Lists relays.

  USAGE
    relay list [FLAGS]

  FLAGS
    -h, --help      Display this usage info
    -g, --group     Group relays by relay group
    -v, --verbose   Include additional relay details
  """

  @doc """
  Lists relays. Accepts a cog request and returns either a success tuple
  containing a template and data, or an error.
  """
  @spec list_relays(%Cog.Messages.Command{}) :: {:ok, String.t, Map.t} | {:error, any()}
  def list_relays(req) do
    if Helpers.flag?(req.options, "help") do
      show_usage
    else
      case Relays.all do
        [] ->
          {:ok, "No relays configured"}
        relays ->
          template = ViewHelpers.template("relay-list", req.options)
          data     = ViewHelpers.render(relays, req.options)
          {:ok, template, data}
      end
    end
  end

  defp show_usage do
    {:ok, "usage", %{usage: @moduledoc}}
  end
end
