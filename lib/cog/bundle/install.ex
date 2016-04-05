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

  @command_attrs ["options", "rules", "documentation"]

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
  * `config_file`: the JSON map of the configuration file

  """
  def install_bundle(bundle_params) do

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

      Map.get(bundle.config_file, "templates", %{})
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
  #     create_command(bundle, %{"options": [%{"name" => "instance-id", "type" => "string", "required" => true}],
  #                              "rules": ["When command is foo:bar must have foo:write"],
  #                              "module" => "Cog.Commands.EC2Tag"})
  defp create_command(%Bundle{}=bundle, {command_name, command_spec}) do
    command_spec = Map.take(command_spec, @command_attrs)

    command = Command.build_new(bundle, Map.put(command_spec, "name", command_name))
    |> Repo.insert!

    Enum.each(command_spec["rules"], &(Cog.RuleIngestion.ingest(&1, false)))

    Map.get(command_spec, "options", [])
    |> Enum.each(&create_option(command, &1))
  end

  defp create_option(command, {option_name, params}) do
    option = Map.merge(%{
      "name" => option_name,
      "long_flag" => option_name
    }, params)

    CommandOption.build_new(command, option)
    |> Repo.insert!
  end

  # TODO: want a better API for this; given a NS and bare names,
  # make the permissions
  defp create_permission(ns, full_name) do
    ns_name = ns.name # for pattern matching
    {^ns_name, name} = Permission.split_name(full_name)
    Permission.build_new(ns, %{name: name})
    |> Repo.insert!
  end

  defp create_template(bundle, {name, %{"provider" => provider, "contents" => contents}}) do
    params = %{
      adapter: provider,
      name: name,
      source: contents
    }

    bundle
    |> Ecto.Model.build(:templates)
    |> Template.changeset(params)
    |> Repo.insert!
  end
end
