defmodule Cog.Repository.BundlesTest do
  use Cog.ModelCase, async: false

  require Logger

  alias Cog.Models.Bundle
  alias Cog.Models.BundleVersion
  alias Cog.Models.Command
  alias Cog.Models.CommandVersion
  alias Cog.Repository.Bundles

  test "on a fresh system, the current operable bundle is the only thing enabled" do
    assert %{"operable" => app_version} == Bundles.enabled_bundles
  end

  test "enabling and disabling bundles is reflected in enabled_bundles/0" do
    {:ok, foo_version} = Bundles.install(%{"name" => "foo", "version" => "1.0.0", "config_file" => %{}})
    {:ok, bar_version} = Bundles.install(%{"name" => "bar", "version" => "2.0.0", "config_file" => %{}})

    :ok = Bundles.set_bundle_version_status(foo_version, :enabled)
    :ok = Bundles.set_bundle_version_status(bar_version, :enabled)

    assert %{"operable" => app_version,
             "foo" => version("1.0.0"),
             "bar" => version("2.0.0")} == Bundles.enabled_bundles

    :ok = Bundles.set_bundle_version_status(bar_version, :disabled)

    assert %{"operable" => app_version,
             "foo" => version("1.0.0")} == Bundles.enabled_bundles
  end

  test "the enabled version of the operable bundle is always the current application version" do
    {:ok, current_version} = Version.parse(app_version_string)

    %BundleVersion{version: embedded_version} = Bundles.enabled_version(bundle_named("operable"))

    assert current_version == embedded_version
  end

  test "the sole site bundle version is fixed" do
    fixed_version = version("0.0.0")
    assert %BundleVersion{version: ^fixed_version, bundle: %Bundle{name: "site"}} = Bundles.site_bundle_version
  end

  Enum.each(["operable", "site", "user"], fn(protected_name) ->
    test "Cannot create a bundle named #{protected_name}" do
      assert {:error, {:reserved_bundle, unquote(protected_name)}} = Bundles.install(%{"name" => unquote(protected_name)})
    end

    unless protected_name == "user" do # There's no actual "user" bundle
      test "Cannot delete the #{protected_name} bundle" do
        bundle = bundle_named(unquote(protected_name))
        assert {:error, {:protected_bundle, unquote(protected_name)}} = Bundles.delete(bundle)
      end

      test "Cannot delete any version of the #{protected_name} bundle" do
        # These bundles can only have 1 version
        [bundle_version] = bundle_named(unquote(protected_name)) |> Bundles.versions
        assert {:error, {:protected_bundle, unquote(protected_name)}} = Bundles.delete(bundle_version)
      end

      test "Cannot enable any version of the #{protected_name} bundle" do
        [bundle_version] = bundle_named(unquote(protected_name)) |> Bundles.versions
        assert {:error, {:protected_bundle, unquote(protected_name)}} = Bundles.set_bundle_version_status(bundle_version, :enabled)
      end

      test "Cannot disable any version of the #{protected_name} bundle" do
        [bundle_version] = bundle_named(unquote(protected_name)) |> Bundles.versions
        assert {:error, {:protected_bundle, unquote(protected_name)}} = Bundles.set_bundle_version_status(bundle_version, :disabled)
      end

    end
  end)

  test "enabled_version/1 and enabled?/1 agree" do
    bundle = bundle_named("operable")
    %BundleVersion{}=enabled_version = Bundles.enabled_version(bundle)
    assert Bundles.enabled?(enabled_version)
  end

  test "status of operable bundle" do
    expected = %{name: "operable",
                 enabled: true,
                 enabled_version: app_version_string,
                 relays: [bot_relay_id]}
    assert expected == Bundles.status(bundle_named("operable"))
  end

  test "status of site bundle" do
    expected = %{name: "site",
                 enabled: false,
                 relays: []}
    assert expected == Bundles.status(bundle_named("site"))
  end

  test "upgrading the embedded bundle activates the new version and deletes the old" do
    current_version = app_version

    {:ok, desired_version} = Version.parse("1000000.0.0") # This should last us a while ;)

    # Verify the current enabled version
    %BundleVersion{id: original_id, version: ^current_version} = Bundles.enabled_version(bundle_named("operable"))

    # "upgrade" it to a later version
    assert %BundleVersion{version: ^desired_version} =
      Bundles.maybe_upgrade_embedded_bundle!(%{"name" => "operable", "version" => to_string(desired_version), "config_file" => %{}})

    # Show the new version is enabled
    assert %BundleVersion{version: ^desired_version} = Bundles.enabled_version(bundle_named("operable"))

    # Verify the old version is gone
    refute Bundles.version(original_id)
  end

  test "'upgrading' the embedded bundle to itself is a no-op" do
    current_version = app_version

    # Verify the current enabled version
    %BundleVersion{version: ^current_version} = Bundles.enabled_version(bundle_named("operable"))

    # "upgrade" it to the same version
    assert %BundleVersion{version: ^current_version} =
      Bundles.maybe_upgrade_embedded_bundle!(%{"name" => "operable", "version" => app_version_string, "config_file" => %{}})

    # Show the same version is still enabled
    assert %BundleVersion{version: ^current_version} = Bundles.enabled_version(bundle_named("operable"))
  end

  test "'upgrading' to a previous version of the embedded bundle is forbidden" do
    current_version = app_version

    {:ok, desired_version} = Version.parse("0.0.1") # This is from before we had versioned bundles

    # Verify the current enabled version
    %BundleVersion{version: ^current_version} = Bundles.enabled_version(bundle_named("operable"))

    # "upgrade" it to a previous version
    assert_raise(RuntimeError,
                 "Unable to downgrade from #{to_string(current_version)} to #{to_string(desired_version)}",
      fn() ->
        Bundles.maybe_upgrade_embedded_bundle!(%{"name" => "operable", "version" => to_string(desired_version), "config_file" => %{}})
      end)

    # Ensure original version is still there
    assert %BundleVersion{version: ^current_version} = Bundles.enabled_version(bundle_named("operable"))

  end

  test "deleting the last version of a bundle deletes the bundle itself" do
    {:ok, version} = Bundles.install(%{"name" => "testing", "version" => "1.0.0", "config_file" => %{}})

    assert %Bundle{name: "testing"} = bundle_named("testing")

    # Returns the bundle if that's what we ultimately delete
    assert {:ok, %Bundle{}} = Bundles.delete(version)

    refute bundle_named("testing")
  end

  test "deleting one of several versions of a bundle just deletes that version" do
    {:ok, version1} = Bundles.install(%{"name" => "testing", "version" => "1.0.0", "config_file" => %{}})
    {:ok, version2} = Bundles.install(%{"name" => "testing", "version" => "2.0.0", "config_file" => %{}})
    {:ok, version3} = Bundles.install(%{"name" => "testing", "version" => "3.0.0", "config_file" => %{}})

    bundle = bundle_named("testing")
    assert %Bundle{name: "testing"} = bundle
    assert 3 == length(Bundles.versions(bundle))

    # Returns the bundle if that's what we ultimately delete
    assert {:ok, %BundleVersion{}} = Bundles.delete(version3)

    bundle_after = bundle_named("testing")
    assert %Bundle{name: "testing"} = bundle_after # bundle's still there!
    versions = Bundles.versions(bundle_after)
    assert 2 == length(versions)
    assert Enum.find(versions, &(&1.id == version1.id))
    assert Enum.find(versions, &(&1.id == version2.id))
  end

  test "deleting an enabled version is not allowed" do
    {:ok, version1} = Bundles.install(%{"name" => "testing", "version" => "1.0.0", "config_file" => %{}})
    :ok = Bundles.set_bundle_version_status(version1, :enabled)

    assert {:error, :enabled_version} = Bundles.delete(version1)

    # Check that the version is still there
    bundle = bundle_named("testing")
    assert version1.id == Bundles.enabled_version(bundle).id
  end

  test "deleting a bundle with an enabled version is not allowed" do
    {:ok, version1} = Bundles.install(%{"name" => "testing", "version" => "1.0.0", "config_file" => %{}})
    :ok = Bundles.set_bundle_version_status(version1, :enabled)

    bundle = bundle_named("testing")
    assert {:error, {:enabled_version, version("1.0.0")}} == Bundles.delete(bundle)

    # Check that the version is still there
    assert version1.id == Bundles.enabled_version(bundle).id
  end

  test "enabling one bundle version disables the others for that bundle" do
    {:ok, version1} = Bundles.install(%{"name" => "testing", "version" => "1.0.0", "config_file" => %{}})
    {:ok, version2} = Bundles.install(%{"name" => "testing", "version" => "2.0.0", "config_file" => %{}})
    {:ok, version3} = Bundles.install(%{"name" => "testing", "version" => "3.0.0", "config_file" => %{}})

    bundle = bundle_named("testing")
    refute Bundles.enabled_version(bundle)

    # This "bystander" version should stay enabled throughout the test
    # to demonstrate the effects are restricted to the 'testing'
    # bundle
    {:ok, bystander1} = Bundles.install(%{"name" => "bystander", "version" => "1.0.0", "config_file" => %{}})
    :ok = Bundles.set_bundle_version_status(bystander1, :enabled)
    assert Bundles.enabled?(bystander1)

    # Enable version 1
    :ok = Bundles.set_bundle_version_status(version1, :enabled)
    assert Bundles.enabled?(version1)
    refute Bundles.enabled?(version2)
    refute Bundles.enabled?(version3)
    assert Bundles.enabled?(bystander1) # still good

    # Now enable version 2; version 1 becomes disabled
    :ok = Bundles.set_bundle_version_status(version2, :enabled)
    refute Bundles.enabled?(version1)
    assert Bundles.enabled?(version2)
    refute Bundles.enabled?(version3)
    assert Bundles.enabled?(bystander1) # still good

    # Now enable version 3; version 2 becomes disabled
    :ok = Bundles.set_bundle_version_status(version3, :enabled)
    refute Bundles.enabled?(version1)
    refute Bundles.enabled?(version2)
    assert Bundles.enabled?(version3)
    assert Bundles.enabled?(bystander1) # still good

    # Now disable version 3; the whole bundle is effectively disabled
    :ok = Bundles.set_bundle_version_status(version3, :disabled)
    refute Bundles.enabled?(version1)
    refute Bundles.enabled?(version2)
    refute Bundles.enabled?(version3)
    refute Bundles.enabled_version(bundle)
    assert Bundles.enabled?(bystander1) # still good
  end

  test "verify existence of a bundle version" do
    assert {:ok, _} = Bundles.verify_version_exists(%{"name" => "operable", "version" => app_version_string})
    assert {:ok, _} = Bundles.verify_version_exists(%{"name" => "site", "version" => "0.0.0"})

    assert {:error, _} = Bundles.verify_version_exists(%{"name" => "testing", "version" => "1.0.0"})
    {:ok, _} = Bundles.install(%{"name" => "testing", "version" => "1.0.0", "config_file" => %{}})
    assert {:ok, _} = Bundles.verify_version_exists(%{"name" => "testing", "version" => "1.0.0"})
  end

  test "find all bundles a command is in" do
    assert ["operable"] == Bundles.bundle_names_for_command("echo")

    {:ok, _} = Bundles.install(%{"name" => "testing",
                                 "version" => "1.0.0",
                                 "config_file" => %{"name" => "testing",
                                                    "version" => "1.0.0",
                                                    "commands" => %{"echo" => %{}}}})

    assert ["operable", "testing"] == Bundles.bundle_names_for_command("echo") |> Enum.sort
  end

  test "appropriate bundle configs are returned for a relays" do
    {relay, _bundle_version, _relay_group} = create_relay_bundle_and_group("testing", bundle_opts: [version: "5.0.0"])

    assert [%{"name" => "bundle-testing",
              "version" => "5.0.0"}] = Bundles.bundle_configs_for_relay(relay.id)

     {:ok, new_version} = Bundles.install(%{"name" => "bundle-testing",
                                  "version" => "6.0.0",
                                  "config_file" => %{"name" => "bundle-testing",
                                                     "version" => "6.0.0"}})

     :ok = Bundles.set_bundle_version_status(new_version, :enabled)

     assert [%{"name" => "bundle-testing",
               "version" => "6.0.0"}] = Bundles.bundle_configs_for_relay(relay.id)
  end

  test "appropriate command version can be retrieved" do
    version = app_version
    command_version = Bundles.command_for_bundle_version("echo", "operable", version)

    assert %CommandVersion{command: %Command{name: "echo",
                                             bundle: %Bundle{name: "operable"}},
                           bundle_version: %BundleVersion{version: ^version}} = command_version

  end

  ########################################################################

  defp bundle_named(name),
    do: Enum.find(Bundles.bundles, &(&1.name == name))

  defp app_version_string,
    do: Application.spec(:cog, :vsn) |> IO.chardata_to_string

  defp app_version,
    do: version(app_version_string)

  defp version(version_string) do
    {:ok, v} = Version.parse(version_string)
    v
  end

  defp bot_relay_id do
    {:ok, %Carrier.Credentials{id: relay_id}} = Carrier.CredentialManager.get()
    relay_id
  end

end
