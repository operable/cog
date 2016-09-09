defmodule Cog.Support.ModelUtilities do
  @moduledoc """
  Utilities for making it easier to interact with models.

  Intended for use in interactive situations and testing fixture
  setup. From your interactive shell prompt, just type:

      iex> import #{inspect __MODULE__}

  and you'll be good to go.

  These functions should use the standard high-level methods for
  operating on models, as appropriate. For instance, insertion into
  the repo of bare model structs should be avoided in favor of using
  changesets. Similarly, models that are the roots of complex graphs
  of models (e.g., bundles, commands, rules) should be inserted using
  API functions that establish the entire graph.

  (That's actually sensible advice, anyway. If you find yourself doing
  bare inserts, here or elsewhere, think whether there is a more
  appropriate method.)

  Additionally, many of these functions may use "dummy data", either
  partially or in full, in order to be easier to use in interactive or
  testing scenarios.

  For example, when creating a user, we don't necessarily care about
  specifying a first name, last name, or even a real password; we just
  want a user in the system. As such, our `user/1` function fills
  in much of this data with sensible defaults. This is *definitely*
  not something to use in production code, though.

  Other functions may actually be legitimately useful in production
  code, to the extent that they do not make such use of fake data. If
  you find yourself wanting to use such code in production, *do not*
  use it directly from this module! Let's have a discussion and talk
  about pulling the specific functions out into a more appropriate
  place.

  To reiterate: this module is *explicitly not* for use in production
  code!
  """

  use Cog.Models
  alias Cog.Repo
  require Logger

  @doc """
  Create a user, filling in dummy data as appropriate.

  ## Options

    Sometimes you want a little more control, so you can pass an
    optional keyword list as a second argument to override some of the
    defaults.

    * `:first_name` - defaults to the value of `username`
    * `:last_name` - defaults to `"Mc\#{username}` ;)

  ## Example

     iex> user("robot")
     %Cog.Models.User{
       id: "fb0708f1-3464-411a-b65a-e3de325aa390",
       username: "robot"
       first_name: "Robot",
       last_name: "McRobot",
       email_address: "robot@operable.io",
       password: nil, # the password is actually "robot"
       password_digest: "$2b$04$me8.bWW9urIiJbTLCCDt1.DPS75.b.nQhdOVQL53BCXCDWmb6ClhC",
       inserted_at: #Ecto.DateTime<2015-11-18T11:53:03Z>,
       updated_at: #Ecto.DateTime<2015-11-18T11:53:03Z>
       # extra fields elided
     }

  """
  def user(username, options \\ []) do
    user = %User{}
    |> User.changeset(%{username: username,
                        first_name: Access.get(options, :first_name, String.capitalize(username)),
                        last_name: Access.get(options, :last_name, "Mc#{String.capitalize(username)}"),
                        email_address: Access.get(options, :email_address, "#{username}@operable.io"),
                        password: username})
    |> Repo.insert!

    # Password is a virtual field that won't be present if we retrieve
    # this user from the database, so test comparisons can fail.
    %User{user | password: nil}
  end

  @doc """
  Assign a new randomly-generated token to `user`. Returns the
  un-modified user for pipelines
  """
  def with_token(%User{}=user) do
    {:ok, _} = Token.insert_new(user, %{value: Token.generate})
    user
  end

  @doc """
  Associate a chat handle for the specified provider with
  `user`. Returns the un-modified user for piplines.
  """
  def with_chat_handle_for(%User{}=internal_user, provider) do
    provider =  ChatProvider |> Repo.get_by!(name: String.downcase(provider))
    handle = internal_user.username
    {:ok, external_user} = Cog.Chat.Adapter.lookup_user(provider.name, handle)
    # TODO Provider ID!!!!!!

    params = %{provider_id: provider.id,
               handle: external_user.handle,
               chat_provider_user_id: external_user.id,
               user_id: internal_user.id}

    %ChatHandle{}
    |> ChatHandle.changeset(params)
    |> Repo.insert!

    internal_user
  end

  @doc """
  Grant a permission to an implementor of `Permittable`, and return
  the implementor.
  """
  def with_permission(grantee, permission_name) when is_binary(permission_name) do
    with_permission(grantee, permission(permission_name))
  end
  def with_permission(grantee, %Permission{}=permission) do
    :ok = Permittable.grant_to(grantee, permission)
    grantee
  end

  @doc """
  Create or retrieve a permission with the given name.

  If either the bundle or the permission do not already exist, they
  are created.

  Example:

      permission("foo:bar")

  """
  def permission(full_name) do
    permission = full_name
    |> Cog.Queries.Permission.from_full_name
    |> Repo.one

    case permission do
      %Permission{} ->
        permission
      nil ->
        # TODO: For now this is fine, but we should come back and make
        # this use Cog.Repository.Permissions.create_permission/2
        # instead... that will require creating or looking up a bundle
        # version, though
        {ns, name} = Permission.split_name(full_name)
        b = case Repo.get_by(Bundle, name: ns) do
              nil ->
                Repo.insert! %Bundle{name: ns}
              bundle ->
                bundle
            end
        Permission.build_new(b, %{name: name}) |> Repo.insert!
    end
  end

  @doc """
  Create a group with the given name
  """
  def group(name) do
    %Group{} |> Group.changeset(%{name: name}) |> Repo.insert!
  end

  @doc """
  Create a role with the given name
  """
  def role(name) do
    %Role{} |> Role.changeset(%{name: name}) |> Repo.insert!
  end

  def role_with_permission(role_name, permission_name) do
    role = role(role_name)
    permission = permission(permission_name)
    :ok = Permittable.grant_to(role, permission)
    {role, permission}
  end

  @doc """
  Create a command with the given name
  """
  def command(name, params \\ %{}) do
    bundle_version = bundle_version("test-bundle")
    bundle = bundle_version.bundle

    command = %Command{}
    |> Command.changeset(%{name: name, bundle_id: bundle.id})
    |> Repo.insert!

    %CommandVersion{}
    |> CommandVersion.changeset(Map.merge(%{command_id: command.id, bundle_version_id: bundle_version.id}, params))
    |> Repo.insert!

    bundle = Map.put(bundle, :bundle_versions, [bundle_version])
    command = Map.put(command, :bundle, bundle)

    command
  end

  @doc """
  Creates a bundle version
  """
  def bundle_version(name, opts \\ []) do
    bundle_template = %{
      "name" => name,
      "version" => "0.1.0",
      "cog_bundle_version" => 4,
      "commands" => %{}
    }

    bundle_config = Enum.into(opts, bundle_template, fn
      ({key, value}) when is_atom(key) ->
        {Atom.to_string(key), value}
      (opt) ->
        opt
    end)

    # TODO what's enabled here?
    #    enabled = Keyword.get(opts, :enabled, false)

    {:ok, bundle_version} = Cog.Repository.Bundles.install(%{"name" => name,
                                                             "version" => bundle_config["version"],
                                                             "config_file" => bundle_config})
    bundle_version
  end

  @doc """
  Creates a relay record

  Options:
  :enabled - set's whether the relay should be enabled on create
  :desc - set's the relays description
  """
  def relay(name, token, opts \\ []) do
    relay = %Relay{}
    |> Relay.changeset(%{name: name,
                         token: token,
                         enabled: Keyword.get(opts, :enabled, false),
                         desc: Keyword.get(opts, :desc, nil)})
    |> Repo.insert!
    %{relay | token: nil}
  end

  @doc """
  Creates a relay group record
  """
  def relay_group(name, desc \\ nil) do
    %RelayGroup{}
    |> RelayGroup.changeset(%{name: name, desc: desc})
    |> Repo.insert!
  end

  @doc """
  Adds a relay to a relay group
  """
  def add_relay_to_group(group_id, relay_id) do
    %RelayGroupMembership{}
    |> RelayGroupMembership.changeset(%{group_id: group_id,
                                        relay_id: relay_id})
    |> Repo.insert!
  end

  @doc """
  Assigns a bundle to a relay group
  """
  def assign_bundle_to_group(group_id, bundle_id) do
    %RelayGroupAssignment{}
    |> RelayGroupAssignment.changeset(%{group_id: group_id,
                                        bundle_id: bundle_id})
    |> Repo.insert!
  end

  @doc """
  Creates a relay, relay-group and bundle. Then assigns the bundle and adds the
  relay to the relay-group

  Options:
  :token - sets the token for the new relay
  :relay_opts - set any additional options for the relay as described by `__MODULE__.relay/3`
  :bundle_opts - options to pass to create a new bundle version
  """
  @spec create_relay_bundle_and_group(String.t, [{Atom.t, any()}]) :: {%Relay{}, %BundleVersion{}, %RelayGroup{}}
  def create_relay_bundle_and_group(name, opts \\ []) do
    relay = relay("relay-#{name}",
                  Keyword.get(opts, :token, "sekrit"),
                  Keyword.get(opts, :relay_opts, []))
    bundle_version = bundle_version("bundle-#{name}", Keyword.get(opts, :bundle_opts, []))

    Cog.Repository.Bundles.set_bundle_version_status(bundle_version, :enabled)

    relay_group = relay_group("group-#{name}")
    add_relay_to_group(relay_group.id, relay.id)
    assign_bundle_to_group(relay_group.id, bundle_version.bundle.id)

    {relay, bundle_version, relay_group}
  end

  @doc """
  Remove everything from the database.

  As this removes bundles, too, we want to terminate any running
  bundle processes, so they won't interfere with anything you might
  reload later.
  """
  def clean_db! do
    [Bundle, User, Group, Relay, Role, Namespace]
    |> Enum.each(&Repo.delete_all/1)

    Supervisor.terminate_child(Cog.Relay.RelaySup, Cog.Bundle.Embedded)
  end

end
