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
  def rule(rule_text, bundle_version \\ Cog.Repository.Bundles.site_bundle_version) do
    {:ok, rule} = Cog.RuleIngestion.ingest(rule_text, bundle_version)
    rule
  end

  def trigger(params \\ %{}) do
    alias Cog.Models.Trigger
    attrs = Map.merge(%{name: "echo",
                        pipeline: "echo $body.message > chat://#general"}, params)
    Trigger.changeset(%Trigger{}, attrs) |> Repo.insert!
  end

end
