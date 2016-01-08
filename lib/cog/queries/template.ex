defmodule Cog.Queries.Template do
  use Cog.Queries
  alias Cog.Models.Template

  def template_source(bundle_id, adapter, name) do
    from t in Template,
    where: t.bundle_id == ^bundle_id and
      t.adapter == ^adapter and
      t.name == ^name,
    select: t.source
  end
end
