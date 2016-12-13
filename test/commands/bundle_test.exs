defmodule Cog.Test.Commands.BundleTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.{List, Versions, Info}
  alias Cog.Repository.Bundles
  import Cog.Support.ModelUtilities, only: [bundle_version: 1,
                                            bundle_version: 2]

  test "listing bundles" do
    bundle_version("test_bundle")

    {:ok, response} = new_req(args: [])
    |> send_req(List)

    bundles = Enum.map(response, &Map.take(&1, [:name]))
    |> Enum.sort

    assert([%{name: "operable"},
            %{name: "test_bundle"}] == bundles)
  end

  test "information about a single bundle" do
    {:ok, response} = new_req(args: ["operable"])
    |> send_req(Info)

    version = Application.fetch_env!(:cog, :embedded_bundle_version)

    assert(%{name: "operable",
             enabled_version: %{version: ^version}} = response)
  end

  test "list versions for a bundle" do
    {:ok, response} = new_req(args: ["operable"])
    |> send_req(Versions)

    version = Application.fetch_env!(:cog, :embedded_bundle_version)

    assert([%{name: "operable",
              version: ^version}] = response)
  end

  test "enable a bundle" do
    bundle_version = bundle_version("test_bundle")

    {:ok, response} = new_req(args: ["enable", "test_bundle"])
    |> send_req()

    assert(response == %{name: "test_bundle", status: "enabled", version: "0.1.0"})
    assert(Bundles.enabled?(bundle_version))
  end

  test "disable a bundle" do
    bundle_version = bundle_version("test_bundle")
    Bundles.set_bundle_version_status(bundle_version, :enabled)

    {:ok, response} = new_req(args: ["disable", "test_bundle"])
    |> send_req()

    assert(response == %{name: "test_bundle", status: "disabled", version: "0.1.0"})
    refute(Bundles.enabled?(bundle_version))
  end

  test "passing an unknown subcommand fails" do
    {:error, error} = new_req(args: ["not-a-subcommand"])
    |> send_req()

    assert(error == "Unknown subcommand 'not-a-subcommand'")
  end

  test "installing a bundle via the registry" do
    bundle = "heroku"
    version = "0.0.4"
    bundle_version = bundle_version(bundle, version: version)

    # We're mocking the install_from_registry function here because it makes a
    # call to the warehouse api. We aren't testing whether or not installing
    # bundles from warehouse works, we just care that the command is making
    # the right function calls. We also only want to mock this specific call,
    # so unless the bundle and version match, we just do a passthrough.
    :meck.new(Bundles, [:passthrough])
    :meck.expect(Bundles, :install_from_registry, fn
                 (^bundle, ^version) ->
                   {:ok, bundle_version}
                 (bundle, version) ->
                   :meck.passthrough([bundle, version])
    end)

    Bundles.bundles()

    {:ok, response} = new_req(args: ["install", bundle, version])
    |> send_req()

    assert(%{name: ^bundle, versions: [%{version: ^version}]} = response)
    assert(:meck.validate(Bundles))
  end
end
