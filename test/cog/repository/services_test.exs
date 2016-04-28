defmodule Cog.Repository.ServicesTest do
  use ExUnit.Case

  @moduletag :services

  alias Cog.Repository.Services

  test "memory service YAML is valid" do
    assert {:ok, _} = Services.service_api("memory")
  end

  test "API for a non-existent service is an error" do
    assert {:error, :not_found} = Services.service_api("not_real")
  end

end
