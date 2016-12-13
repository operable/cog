defmodule Cog.Test.Commands.Bundle.InstallTest do
  use Cog.CommandCase, command_module: Cog.Commands.Bundle

  alias Cog.Commands.Bundle.Install
  alias Cog.Repository.Bundles
  import Cog.Support.ModelUtilities, only: [bundle_version: 2]

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

    {:ok, response} = new_req(args: [bundle, version])
    |> send_req(Install)

    assert(%{name: ^bundle, versions: [%{version: ^version}]} = response)
    assert(:meck.validate(Bundles))
  end
end
