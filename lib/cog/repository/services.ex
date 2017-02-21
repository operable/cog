defmodule Cog.Repository.Services do

  @moduledoc """
  Behavioral API for interacting with services.
  """

  @doc """
  Retrieve all currently-running services. Order is undefined.
  """
  @spec all :: [map]
  def all do
    # TODO: Eventually, we'll want to introspect the system for this
    # information. For now, though, this will be effectively duplicating
    # information contained in the service router.
    [
      %{name: "memory", version: "1.0.0"},
      %{name: "chat", version: "1.0.0"}
    ]
  end

  def deployed(name),
    do: Enum.find(all, &(&1[:name] == name))

end
