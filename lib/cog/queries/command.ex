defmodule Cog.Queries.Command do
  use Cog.Queries
  alias Cog.Models

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

    from c in Command,
    join: b in assoc(c, :bundle),
    where: b.name == ^bundle,
    where: c.name == ^command
  end


  def rules_for_cmd(name) do
    {ns, name} = Models.Command.split_name(name)
    bundle = Cog.Repo.one(Ecto.Query.from(b in Cog.Models.Bundle,
                                           where: b.name == ^ns))
    from r in Rule,
    join: c in assoc(r, :command),
    where: c.name == ^name,
    where: c.bundle_id == ^bundle.id
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

  # Split a string as though it were a qualified name
  defp is_qualified?(name),
    do: length(String.split(name, ":", parts: 2)) == 2

end
