defmodule Cog.Queries.Command do
  use Cog.Queries
  alias Cog.Models

  def names do
    from c in Command,
    join: b in assoc(c, :bundle),
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

  def options_for(%Command{id: id}) do
    from co in CommandOption,
    where: co.command_id == ^id,
    order_by: co.required
  end

  def rules_for(%Command{id: id}) do
    from r in Rule,
    where: r.command_id == ^id
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

end
