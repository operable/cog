defmodule Cog.Repository.Services do

  @memory_schema_file Path.join([:code.priv_dir(:cog), "swagger", "services", "memory.yaml"])
  @external_resource @memory_schema_file
  @memory_schema File.read!(@memory_schema_file)

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
    [%{name: "memory",
       version: "1.0.0"}]
  end

  @doc """
  Return the Swagger-formatted API information for the given service,
  if it is currently deployed.
  """
  def service_api("memory"),
    do: {:ok, YamlElixir.read_from_string(@memory_schema)}
  def service_api(_),
    do: {:error, :not_found}

end
