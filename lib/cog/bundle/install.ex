defmodule Cog.Bundle.Install do
  @moduledoc """

  Utilities for installing bundles from a number of different sources.

  Currently can install bundles from:
  * remote locations by downloading from a URL
  * a local bundle file
  * embedded bundles

  """
  use Cog.Models

  alias Cog.Bundle.BundleCatalog
  alias Cog.Repo

  require Logger

  @work_dir "cog_bundle_install_working_directory"

  def install(uri) do
    dir = unbundle(uri)

    Logger.info("Copied bundle: #{dir}")

    bundle = install_from_path(dir)

    Logger.info("Created bundle: #{bundle.name}")

    # TODO: should this be down in install_bundle? To make sure all
    # paths get it?
    {:ok, _} = BundleCatalog.load_bundle(bundle)

    Logger.info("Started bundle: #{bundle.name}")
  end

  @doc """
  Given the `path` to a single bundle on the filesystem, creates and
  inserts all the relevant database records for it.

  This includes:
  * the bundle record itself
  * records for any commands the bundle brings
  * records for any command options those commands have

  Returns the bundle struct.
  """
  def install_from_path(path) do
    config = read_config(path)
    manifest = read_manifest(path)

    %{"bundle" => %{"name" => name}} = config

    install_bundle(%{name: name,
                     manifest_file: manifest,
                     config_file: config})
  end

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

    {:ok, bundle} = Repo.transaction(fn ->
      bundle = %Bundle{}
      |> Bundle.changeset(bundle_params)
      |> Repo.insert!

      # create permission namespace
      # TODO: want to have a build_new function for this
      ns = %Namespace{}
      |> Namespace.changeset(%{name: bundle.name, bundle_id: bundle.id})
      |> Repo.insert!

      bundle.config_file["permissions"]
      |> Enum.each(&create_permission(ns, &1))

      bundle.config_file["commands"]
      |> Enum.each(&create_command(bundle, &1))

      bundle.config_file["rules"]
      |> Enum.each(&Cog.RuleIngestion.ingest/1)

      Map.get(bundle.config_file, "templates", [])
      |> Enum.each(&create_template(bundle, &1))

      bundle
    end)
    bundle
  end

  defp unbundle(uri) do
    if File.exists?(uri) do
      unbundle_local(uri)
    else
      path = download(uri)
      bundle_path = unbundle_local(path)
      File.rm_rf!(path)
      bundle_path
    end
  end

  defp unbundle_local(path) do
    tmp_dir = Path.join(System.tmp_dir!, @work_dir)
    File.mkdir_p!(tmp_dir)

    Logger.info("Writing to #{tmp_dir}")

    unzip(path, tmp_dir)

    root = bundle_root
    Logger.info("Copying #{tmp_dir} -> #{root}")

    File.mkdir_p!(root)
    File.cp_r!(tmp_dir, root)

    [name] = File.ls!(tmp_dir)
    bundle_path = Path.join(root, name)

    File.rm_rf!(tmp_dir)

    bundle_path
  end

  defp download(uri) do
    case HTTPotion.get(uri) do
      %{status_code: 200, body: body} ->
        tmp_dir = Path.join(System.tmp_dir!, @work_dir)
        File.mkdir_p!(tmp_dir)

        name = name_from_uri(uri)
        path = Path.join(tmp_dir, name)
        File.write!(path, body)

        path
      %{status_code: code} = response when code in [301, 302] ->
        Keyword.get(response.headers, :Location)
        download(uri)
    end
  end

  defp unzip(src, dest) do
    src = String.to_char_list(src)
    {:ok, _} = :zip.unzip(src, [cwd: dest])
  end

  defp name_from_uri(uri) do
    %{path: path} = URI.parse(uri)
    Path.basename(path)
  end

  # TODO: put this in the config module
  defp read_config(path) do
    path
    |> Path.join("config.json")
    |> File.read!
    |> Poison.decode!
  end

  # TODO: put this in the manifest module
  defp read_manifest(path) do
    path
    |> Path.join("manifest.json")
    |> File.read!
    |> Poison.decode!
  end

  # Given the parent `bundle` and the bundle configuration schema for a
  # single command, inserts records into the database for that
  # command. This includes any command options.
  #
  # ## Example
  #
  #     create_command(bundle, %{"name" => "ec2-tag",
  #                              "enforcing" => true,
  #                              "version" => "0.0.1",
  #                              "options": [%{"name" => "instance-id", "type" => "string", "required" => true}],
  #                              "module" => "Cog.Commands.EC2Tag"})
  defp create_command(%Bundle{}=bundle, command_spec) do
    %{"name" => name,
      "version" => version,
      "options" => options,
      "enforcing" => enforcing,
      "documentation" => documentation} = command_spec

    command = Command.build_new(bundle, %{name: name, version: version,
                                          documentation: documentation,
                                          enforcing: enforcing})
    |> Repo.insert!

    executable = command_spec["executable"]
    if executable do
      executable_path = Path.join([bundle_root, bundle.name, executable])
      Logger.debug("Making #{executable_path} executable")
      File.chmod!(executable_path, 0o744)
    end

    for option <- options do
      create_option(command, option)
    end
  end

  defp create_option(command, params) do
    CommandOption.build_new(command, params) |> Repo.insert!
  end

  defp bundle_root do
    Application.get_env(:cog, Cog.Bundle.BundleSup)
    |> Keyword.fetch!(:bundle_root)
  end

  # TODO: want a better API for this; given a NS and bare names,
  # make the permissions
  defp create_permission(ns, full_name) do
    ns_name = ns.name # for pattern matching
    {^ns_name, name} = Permission.split_name(full_name)
    Permission.build_new(ns, %{name: name})
    |> Repo.insert!
  end

  defp create_template(bundle, %{"adapter" => adapter, "name" => name, "source" => source}) do
    params = %{
      adapter: adapter,
      name: name,
      source: source
    }

    bundle
    |> Ecto.Model.build(:templates)
    |> Template.changeset(params)
    |> Repo.insert!
  end
end
