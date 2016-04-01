defmodule Cog.Queries.Template do
  use Cog.Queries
  alias Cog.Models.Template

  def template_source(adapter, nil, name) do
    from t in Template,
    where: is_nil(t.bundle_id) and
      t.adapter == ^adapter and
      t.name == ^name,
    select: t.source
  end

  def template_source(adapter, bundle_id, name) do
    from t in Template,
    where: t.bundle_id == ^bundle_id and
      t.adapter == ^adapter and
      t.name == ^name,
    select: t.source
  end
end
