defmodule Cog.Queries.Command do

  import Ecto.Query, only: [from: 2]

  alias Cog.Models.Command

  def names do
    from c in Command,
    join: b in assoc(c, :bundle),
    select: [b.name, c.name]
  end

  def names_for(enabled) do
    from c in Command,
    join: b in assoc(c, :bundle),
    where: b.enabled == ^enabled,
    select: [b.name, c.name]
  end

  def bundle_for(name) do
    from c in Command,
    join: b in assoc(c, :bundle),
    where: c.name == ^name,
    select: b.name
  end

  def named(name) do
    {bundle, command} = Command.split_name(name)
    named(bundle, command)
  end

  def named(bundle, command) do
    from c in Command,
    join: b in assoc(c, :bundle),
    where: b.name == ^bundle,
    where: c.name == ^command
  end

  def by_name(command) do
    from c in Command,
    where: c.name == ^command
  end

  def with_bundle(queryable),
    do: from c in queryable, preload: [:bundle]

  def with_rules(queryable),
    do: from c in queryable, preload: [rules: [permissions: :namespace]]

  def with_options(queryable),
    do: from c in queryable, preload: [options: :option_type]

  @doc """
  Retrieve all information about a command
  """
  def complete_command(bundle_name, command_name) do
    named(bundle_name, command_name)
    |> with_bundle
    |> with_rules
    |> with_options
  end

  @doc """
  Given a qualified name, query the one command so named (if
  any). If given an unqualified name, query all commands so named.

  In all cases, the corresponding bundle comes preloaded, useful for
  reconstituting the fully-qualified name of each command.
  """
  def by_any_name(name) do
    if is_qualified?(name) do
      from c in (named(name)),
      preload: [:bundle]
    else
      from c in Command,
      where: c.name == ^name,
      preload: [:bundle]
    end
  end

  def sorted_by_qualified_name(query \\ Command) do
    from c in query,
    join: b in assoc(c, :bundle),
    order_by: [b.name, c.name],
    preload: [:bundle]
  end

  def enabled(query \\ Command) do
    from c in query,
    join: b in assoc(c, :bundle),
    where: b.enabled
  end

  def disabled(query \\ Command) do
    from c in query,
    join: b in assoc(c, :bundle),
    where: not(b.enabled)
  end

  # Split a string as though it were a qualified name
  defp is_qualified?(name),
    do: length(String.split(name, ":", parts: 2)) == 2
end
