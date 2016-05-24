defmodule Cog.Repository.Bundles do

  require Ecto.Query
  import Ecto.Query, only: [from: 2]

  require Logger

  alias Cog.Repo
  alias Cog.Models.{Bundle, BundleVersion, CommandVersion}
  alias Cog.Repository.Rules

  alias Cog.Models.Types.VersionTriple
  alias Ecto.Adapters.SQL
  import Cog.UUID, only: [uuid_to_bin: 1]

  @reserved_bundle_names [
    Cog.embedded_bundle,
    Cog.site_namespace,
    "user" # a bundle named "user" would break alias resolution
  ]

  @permanent_site_bundle_version "0.0.0"

  ########################################################################
  # CRUD Operations

  # TODO: toggle inner transaction on or off as needed
  @doc """
  Install a new bundle version. Creates the parent bundle if necessary.

  Note that the following bundle names are reserved; you cannot create
  a bundle with one of these names:

      #{inspect @reserved_bundle_names}

  """
  def install(%{"name" => reserved}) when reserved in @reserved_bundle_names,
    do: {:error, {:reserved_bundle, reserved}}
  def install(params),
    do: __install(params)

  # TODO: clean this up so we only need the config file part;
  # everything else is redundant
  defp __install(%{"name" => _name, "version" => _version, "config_file" => _config}=params) do
    case install_bundle(params) do
      {:ok, bundle_version} ->
        {:ok, preload(bundle_version)}
      {:error, _}=error ->
        error
    end
  end

  @doc """
  Return all known versions for `bundle`. Ensures that all required
  data is appropriately preloaded on the model.
  """
  def versions(%Bundle{}=bundle) do
    bundle = Repo.preload(bundle, :versions)
    preload(bundle.versions)
  end

  # TODO: error tuple or nil?
  def version(id) do
    case Repo.one(from bv in BundleVersion,
                  where: bv.id == ^id,
                  preload: :bundle) do
      nil ->
        nil
      bundle_version ->
        preload(bundle_version)
    end
  end

  @doc """
  Return all bundles in the system.
  """
  def bundles,
    do: Repo.all(Bundle) |> preload

  @doc """
  Retrieve the bundle identified by `id`.
  """
  def bundle(id) do
    case Repo.get(Bundle, id) do
      nil -> nil
      bundle ->
        preload(bundle)
    end
  end

  @doc """
  Delete a bundle version, or an entire bundle (i.e., all versions for
  that bundle). You can only delete versions that are not currently
  enabled, and can only delete bundles if no version is enabled.
  """
  def delete(%BundleVersion{bundle: %Bundle{name: protected}}) when protected in @reserved_bundle_names,
    do: {:error, {:protected_bundle, protected}}
  def delete(%Bundle{name: protected}) when protected in @reserved_bundle_names,
    do: {:error, {:protected_bundle, protected}}
  def delete(%BundleVersion{}=bv) do
    if enabled?(bv) do
      {:error, :enabled_version}
    else
      if length(versions(bv.bundle)) == 1 do
        # this is the last version; just get rid of the entire bundle
        Repo.delete(bv.bundle)
      else
        # Just delete the version
        Repo.delete(bv)
      end
    end
  end
  def delete(%Bundle{}=b) do
    case enabled_version(b) do
      nil ->
        Repo.delete(b)
      %BundleVersion{version: version} ->
        {:error, {:enabled_version, version}}
    end
  end

  ########################################################################
  # Enabled/Disabled Status

  def set_bundle_version_status(%BundleVersion{bundle: %Bundle{name: protected}}, _) when protected in @reserved_bundle_names,
    do: {:error, {:protected_bundle, protected}}
  def set_bundle_version_status(bundle_version, status) when status in [:enabled, :disabled],
    do: __set_bundle_version_status(bundle_version, status)

  # Private implementation that we can use to ensure that the right
  # thing happens for our protected bundles
  defp __set_bundle_version_status(bundle_version, status) do
    stored_procedure_name = case status do
                              :enabled  -> "enable_bundle_version"
                              :disabled -> "disable_bundle_version"
                            end
    with({:ok, db_version} <- VersionTriple.dump(bundle_version.version)) do
      SQL.query!(Repo,
                 "SELECT #{stored_procedure_name}($1, $2)",
                 [uuid_to_bin(bundle_version.bundle.id),
                  db_version])
      :ok
    end
  end

  def enabled?(%BundleVersion{id: id}) do
    query = (from bv in BundleVersion,
             join: e in "enabled_bundle_versions", on: bv.bundle_id == e.bundle_id and bv.version == e.version,
             where: bv.id == ^id)
    case Repo.one(query) do
      nil -> false
      %BundleVersion{id: ^id} -> true
    end
  end

  @doc """
  For the given `bundle`, retrieve the currently-enabled version of
  that bundle, if any is enabled.
  """
  def enabled_version(%Bundle{id: id}) do
    query = (from bv in BundleVersion,
             join: b in assoc(bv, :bundle),
             join: e in "enabled_bundle_versions", on: bv.bundle_id == e.bundle_id and bv.version == e.version,
             where: b.id == ^id)

    case Repo.one(query) do
      nil ->
        nil
      bundle_version ->
        preload(bundle_version)
    end
  end

  def status(%Bundle{}=bundle) do
    case enabled_version(bundle) do
      %BundleVersion{}=bv ->
        %{name: bv.bundle.name,
          enabled: true,
          enabled_version: to_string(bv.version),
          relays: Cog.Relay.Relays.relays_running(bv.bundle.name, bv.version)}
      nil ->
        %{name: bundle.name,
          enabled: false,
          relays: []}
    end
  end

  @doc """
  Returns a map of bundle name to enabled version for all enabled
  bundles. Currently, only one version of any bundle may be enabled at
  a time.
  """
  def enabled_bundles do
    query = (from e in "enabled_bundle_versions",
             join: bv in "bundle_versions_v2", on: bv.bundle_id == e.bundle_id and bv.version == e.version,
             join: b in "bundles_v2", on: bv.bundle_id == b.id,
             select: {b.name, bv.version})

    # TODO: Need to filter out "site" bundle (if some version of this
    # query gets used in the end

    query
    |> Repo.all
    |> Enum.reduce(%{}, fn({name, db_version}, acc) ->
      {:ok, version} = VersionTriple.load(db_version)
      Map.put(acc, name, version)
    end)
  end

  ########################################################################

  # Used in Cog.Relay.Relays to verify the existence of the the bundle
  # versions a relay claims to be serving

  # TODO: maybe turn this into `version_exists?(name, version_string)`?
  def verify_version_exists(%{"name" => bundle_name, "version" => version}) do
    case Repo.one(bundle_version(bundle_name, version)) do
      %BundleVersion{}=bundle_version ->
        # TODO: Where this is used, we really only need the name and
        # version string, and nothing else
        bv = Repo.preload(bundle_version, :bundle)
        {:ok, bv}
      nil ->
        {:error, bundle_name} # TODO might need version in this, too
    end
  end

  @doc """
  The embedded bundle version automatically gets upgraded with each
  new release of Cog. This version is always enabled, by definition,
  and cannot be disabled.
  """
  # TODO: this all needs to be transactional, for maximum safety
  def maybe_upgrade_embedded_bundle!(%{"name" => bundle_name, "version" => version} = config) do
    upgrade_to_current = fn() ->
        case __install(%{"name" => bundle_name, "version" => version, "config_file" => config}) do
          {:ok, latest_version} ->
            :ok = delete_outdated_embedded_version(latest_version)
            postprocess_embedded_bundle_version(latest_version)
          {:error, reason} ->
            raise "Unable to install embedded bundle: #{inspect reason}"
        end
    end

    case active_embedded_bundle_version do
      nil ->
        upgrade_to_current.()
      %BundleVersion{}=installed ->
        case Version.compare(installed.version, version) do
          :lt ->
            upgrade_to_current.()
          :eq ->
            postprocess_embedded_bundle_version(installed)
          :gt ->
            raise "Unable to downgrade from #{installed.version} to #{version}"
        end
    end
  end

  # We only need to have the latest version of the embedded bundle in
  # the system. Since it's currently implemented in Elixir, and uses
  # core bot code directly, switching back to an older version of the
  # bundle would likely break all the commands in the bundle,
  # particularly since the actual Elixir code for those old versions
  # isn't around!
  #
  # As such, we just make sure that the only version of the embedded
  # bundle present is the one that corresponds to the currently
  # running Cog software.
  defp delete_outdated_embedded_version(%BundleVersion{}=current_version) do
    bundle_id = current_version.bundle.id
    version = current_version.version
    query = (from bv in BundleVersion,
             where: bv.bundle_id == ^bundle_id,
             where: bv.version != ^version)

    Repo.delete_all(query)
    :ok
  end

  defp postprocess_embedded_bundle_version(bundle_version) do
    bundle_version = preload(bundle_version)
    __set_bundle_version_status(bundle_version, :enabled)
    bundle_version
  end

  # TODO: Might not need this function after all, pending refactorings
  # mentioned in Cog.Bundle.Embedded.
  @doc """
  Returns the active version of the embedded command bundle, which is
  always the most recently installed one.
  """
  def active_embedded_bundle_version do
    # Eventually, once we put in properly enabled bundle management
    # for the embedded bundle, this will change, but for now, we'll
    # just select the highest-version of the bundle.
    #
    # Yay, abstraction!
    embedded_name = Cog.embedded_bundle

    Repo.one(from bv in BundleVersion,
             join: b in assoc(bv, :bundle),
             where: b.name == ^embedded_name,
             order_by: [desc: bv.version],
             limit: 1,
             preload: :bundle)
  end

  @doc """
  The `site` bundle is special in a handful of ways, one of which is
  that there is only one version of it, ever. This returns that one
  version on-demand.
  """
  def site_bundle_version,
    do: Repo.one!(site_bundle_version_query)

  @doc """
  Called at system-startup to ensure the site bundle is appropriately set up.
  """
  def ensure_site_bundle do
    case Repo.one(site_bundle_version_query) do
      nil ->
        {:ok, _} = __install(%{"name" => Cog.site_namespace,
                               "version" => @permanent_site_bundle_version,
                               "config_file" => %{}})
        :ok
      %BundleVersion{} ->
        :ok
    end
  end

  defp site_bundle_version_query do
    site = Cog.site_namespace

    from bv in BundleVersion,
    join: b in assoc(bv, :bundle),
    where: b.name == ^site,
    where: bv.version == @permanent_site_bundle_version,
    preload: :bundle
  end

  @doc """
  Given the name of a command, and the name and version of a bundle,
  return the specific details for that command in that bundle version.

  This is what the Executor will be calling to figure out exactly
  which command it should be preparing to execute.
  """
  def command_for_bundle_version(command_name, bundle_name, bundle_version) do
    query = (from cv in CommandVersion,
             join: bv in assoc(cv, :bundle_version),
             join: b in assoc(bv, :bundle),
             join: c in assoc(cv, :command),
             where: bv.version == ^bundle_version,
             where: b.name == ^bundle_name,
             where: c.name == ^command_name,

             # command and bundle are needed in order to access the names
             # TODO: Do we need bundle on bundle_version?
             preload: [:bundle_version,
                       options: :option_type,
                       command: [:bundle, :rules]])
    Repo.one(query)
  end

  @doc """
  Given a bare command name, find the names of all bundles that
  provide it.

  Used to help disambiguate unqualified command invocations in the
  Executor.
  """
  def bundle_names_for_command(command_name) do
    Repo.all(from b in Bundle,
             join: c in assoc(b, :commands),
             where: c.name == ^command_name,
             select: b.name)
  end

  @doc """
  Given a relay ID, return all the configurations for the bundle
  versions that it is currently assigned.
  """
  def bundle_configs_for_relay(relay_id) do
    # NOTE: This currently won't return anything for the bot's "relay
    # ID", because there isn't a corresponding "fake relay group" that
    # it belongs to, and which is assigned the embedded bundle.
    #
    # That ends up working out OK, though, because this function is
    # only called in response to real Relays.
    Repo.all(from bv in BundleVersion,
             join: e in "enabled_bundle_versions", on: bv.bundle_id == e.bundle_id and bv.version == e.version,
             join: b in assoc(bv, :bundle),
             join: rg in assoc(b, :relay_groups),
             join: r in assoc(rg, :relays),
             where: r.id == ^relay_id,
             select: bv.config_file)
  end

  ########################################################################

  defp bundle_version(name, version) do
    from bv in BundleVersion,
    join: b in assoc(bv, :bundle),
    where: b.name == ^name,
    where: bv.version == ^version
  end






  defp find_or_create_bundle(name) do
    bundle = case Repo.get_by(Bundle, name: name) do
               %Bundle{}=bundle ->
                 bundle
               nil ->
                 %Bundle{}
                 |> Bundle.changeset(%{name: name})
                 |> Repo.insert!
             end
    preload(bundle)
  end


  # TODO: This raises an exception if it can't insert... is this
  # globally OK?
  defp new_version(bundle, params) do
    bundle
    |> Ecto.Model.build(:versions)
    |> BundleVersion.changeset(params)
    |> Repo.insert!
    |> preload
  end

  # Consolidate what we need to preload for various things so we stay
  # consistent
  @bundle_preloads [:versions, :permissions, :commands]
  @bundle_version_preloads [bundle: @bundle_preloads]

  defp preload(%Bundle{}=bundle),
    do: Repo.preload(bundle, @bundle_preloads)
  defp preload([%Bundle{} | _]=bs),
    do: Repo.preload(bs, @bundle_preloads)
  defp preload(%BundleVersion{}=bv),
    do: Repo.preload(bv, @bundle_version_preloads)
  defp preload([%BundleVersion{} | _]=bvs),
    do: Repo.preload(bvs, @bundle_version_preloads)


  ########################################################################
  #
  # Below here used to be the old Cog.Bundle.Install module. This code
  # rightfully belongs in the module now, though
  #
  ########################################################################


  use Cog.Models

  defp install_bundle(bundle_params) do
    Repo.transaction(fn ->

      # Create a bundle record if it doesn't exist yet
      bundle = find_or_create_bundle(bundle_params["name"])

      # Create a new version record
      version = new_version(bundle, bundle_params)

      # Add permissions, after deduping
      :ok = register_permissions_for_version(version)

      # Add commands, after deduping
      commands = register_commands_for_version(version)

      # Add command_versions; rules get ingested in this process as
      # well
      version.config_file
      |> Map.get("commands", %{})
      |> Enum.each(&create_command_version(version, commands, &1))


      # Add templates
      version.config_file
      |> Map.get("templates", %{})
      |> Enum.each(&create_template(version, &1))

      version
    end)
  end

  # Given the parent `bundle` and the bundle configuration schema for a
  # single command, inserts records into the database for that
  # command. This includes any command options.
  defp create_command_version(%BundleVersion{}=bundle_version,
                              all_commands,
                              {command_name, command_spec}) do

    canonical_command = Enum.find(all_commands, &(&1.name == command_name))

    command_version = bundle_version
    |> Ecto.Model.build(:commands)
    |> Map.put(:command_id, canonical_command.id)
    |> CommandVersion.changeset(command_spec)
    |> Repo.insert!

    command_spec
    |> Map.get("rules", [])
    |> Enum.each(&(Rules.ingest_without_transaction(&1, bundle_version)))

    command_spec
    |> Map.get("options", [])
    |> Enum.each(&create_option(command_version, &1))
  end

  defp create_option(command_version, {option_name, params}) do
    option = Map.merge(%{"name" => option_name,
                         "long_flag" => option_name},
                       params)

    CommandOption.build_new(command_version, option)
    |> Repo.insert!
  end

  defp create_template(bundle_version, {name, template}) do
    Enum.each(template, fn({provider, contents}) ->
      params = %{
        adapter: provider,
        name: name,
        source: contents
      }

      bundle_version
      |> Ecto.Model.build(:templates)
      |> Template.changeset(params)
      |> Repo.insert!
    end)
  end

  defp register_permissions_for_version(bundle_version) do
    bundle = bundle_version.bundle

    # Get just raw names... they'll come in as fully-qualified
    raw_names = bundle_version.config_file
    |> Map.get("permissions", [])
    |> Enum.map(&raw_name/1)
    |> MapSet.new

    # Determine which of those already exist in the database
    bundle_permission_names = Enum.map(bundle.permissions, &(&1.name)) |> MapSet.new

    new_to_this_version  = MapSet.difference(raw_names, bundle_permission_names)

    already_existing_names = MapSet.intersection(raw_names, bundle_permission_names)
    already_existing = Enum.filter(bundle.permissions, &(Enum.member?(already_existing_names, &1.name)))

    # Create new permissions the ones we haven't seen yet
    new_to_this_version
    |> Enum.map(&Cog.Repository.Permissions.create_permission(bundle_version, &1))
    |> Enum.map(fn({:ok, p}) -> p end)

    # Link preexisting permissions to the current bundle version
    Enum.each(already_existing, &Cog.Repository.Permissions.link_permission_to_bundle_version(bundle_version, &1))

    :ok
  end

  defp register_commands_for_version(bundle_version) do
    # TODO: preload commands onto bundle
    bundle = bundle_version.bundle

    # Figure out what commands we need for this bundle version
    command_names = bundle_version.config_file
    |> Map.get("commands", %{})
    |> Map.keys
    |> MapSet.new

    # Determine which of those already exist in the database
    existing_command_names = Enum.map(bundle.commands, &(&1.name)) |> MapSet.new
    missing_command_names  = MapSet.difference(command_names, existing_command_names)

    # Create new commands for the remaining ones, if any
    new_commands = Enum.map(missing_command_names, &add_bundle_command(bundle, &1))

    # Link ALL the permissions to the current bundle version
    all_commands = Enum.concat([bundle.commands, new_commands])


    # Now we need to actually make versioned commands linked to the
    # high-level commands we just made and to the bundle for this
    # version
    #
    # Perhaps we'll do that in a separate function for now
    all_commands
  end

  defp raw_name(permission_name) do
    {_, name} = Permission.split_name(permission_name)
    name
  end

  defp add_bundle_command(bundle, command_name) do
    bundle
    |> Ecto.Model.build(:commands)
    |> Command.changeset(%{name: command_name})
    |> Repo.insert!
  end

end
