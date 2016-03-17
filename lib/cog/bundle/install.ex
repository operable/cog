defmodule Cog.Bundle.Install do
  @moduledoc """

  Utilities for installing bundles from a number of different sources.

  Currently can install bundles from:
  * remote locations by downloading from a URL
  * a local bundle file
  * embedded bundles

  """
  use Cog.Models

  alias Cog.Repo

  require Logger

  @command_attrs ["name", "options", "enforcing",
                  "calling_convention", "execution",
                  "documentation"]

  @doc """
  Given a map of bundle parameters, fully installs the bundle into the
  database.

  All paths of bundle installation lead here; it is also used for
  installing our embedded bundle, and is useful for testing.

  Installing a bundle entails the following:
  * A bundle is created
  * a permission namespace tied to the bundle is created
  * All permissions required by bundle commands are created in the namespace
  * All commands are entered into the database
  * All default rules are created

  ## Parameters

  * `name`: the name of the bundle
  * `manifest_file`: the JSON map of the bundle manifest
  * `config_file`: the JSON map of the configuration file

  """
  # TODO: consider removing manifest until we're actually doing
  # something with them
  def install_bundle(bundle_params) do
    # TODO: Validate bundle (e.g., check manifest, etc)

    Repo.transaction(fn ->
      bundle = %Bundle{}
      |> Bundle.changeset(bundle_params)
      |> Repo.insert!

      # create permission namespace
      # TODO: want to have a build_new function for this
      ns = %Namespace{}
      |> Namespace.changeset(%{name: bundle.name, bundle_id: bundle.id})
      |> Repo.insert!

      Map.get(bundle.config_file, "permissions", [])
      |> Enum.each(&create_permission(ns, &1))

      bundle.config_file["commands"]
      |> Enum.each(&create_command(bundle, &1))

      Map.get(bundle.config_file, "rules", [])
      |> Enum.each(&(Cog.RuleIngestion.ingest(&1, false)))

      Map.get(bundle.config_file, "templates", [])
      |> Enum.each(&create_template(bundle, &1))

      bundle
    end)
  end

  # Given the parent `bundle` and the bundle configuration schema for a
  # single command, inserts records into the database for that
  # command. This includes any command options.
  #
  # ## Example
  #
  #     create_command(bundle, %{"name" => "ec2-tag",
  #                              "enforcing" => true,
  #                              "calling_convention" => "bound",
  #                              "execution" => "multiple",
  #                              "options": [%{"name" => "instance-id", "type" => "string", "required" => true}],
  #                              "module" => "Cog.Commands.EC2Tag"})
  defp create_command(%Bundle{}=bundle, command_spec) do
    command_spec = Map.take(command_spec, @command_attrs)

    command = Command.build_new(bundle, command_spec)
    |> Repo.insert!

    for option <- command_spec["options"] do
      create_option(command, option)
    end
  end

  defp create_option(command, params) do
    CommandOption.build_new(command, params) |> Repo.insert!
  end

  # TODO: want a better API for this; given a NS and bare names,
  # make the permissions
  defp create_permission(ns, full_name) do
    ns_name = ns.name # for pattern matching
    {^ns_name, name} = Permission.split_name(full_name)
    Permission.build_new(ns, %{name: name})
    |> Repo.insert!
  end

  defp create_template(bundle, %{"adapter" => adapter, "name" => command_name, "source" => source}) do
    params = %{
      adapter: adapter,
      name: command_name,
      source: source
    }

    bundle
    |> Ecto.Model.build(:templates)
    |> Template.changeset(params)
    |> Repo.insert!
  end
end
