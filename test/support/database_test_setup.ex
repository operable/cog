defmodule DatabaseTestSetup do
  use Cog.Models
  alias Cog.Repo

  @doc """
  Given a list of groups, nest them in each other, in order.

  Example:

      nest_group_chain([outer, middle, inner])

    will yield the following structure:

      outer --contains--> middle --contains--> inner
  """
  def nest_group_chain([_]) do
    :ok
  end
  def nest_group_chain([outer,inner|rest]) do
    :ok = Groupable.add_to(inner, outer)
    nest_group_chain([inner] ++ rest)
  end

  @doc """
  Create a command with the given name
  """
  def command(name) do
    bundle = case Repo.get_by(Bundle, name: "cog") do
      nil ->
        bundle("cog")
      bundle ->
        bundle
    end

    %Command{}
    |> Command.changeset(%{name: name, bundle_id: bundle.id})
    |> Repo.insert!
  end

  @doc """
  Create a bundle with the given name
  """
  #  TODO: FIXME
  def bundle(name) do
    %Bundle{}
    |> Bundle.changeset(%{name: name, config_file: %{}, manifest_file: %{}})
    |> Repo.insert!
  end

  @doc """
  Create a `Piper.Permissions.Ast.Rule` from the given rule text.
  """
  def expr(rule_text) do
    {:ok, expr, _} = Piper.Permissions.Parser.parse(rule_text)
    expr
  end

  @doc """
  Create and insert into the database a `Cog.Models.Rule` from a
  valid rule text.

  Requires all mentioned commands and permissions to be present in the
  database beforehand.
  """
  def rule(rule_text) do
    {:ok, rule} = Cog.RuleIngestion.ingest(rule_text)
    rule
  end
end
