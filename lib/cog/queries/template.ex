defmodule Cog.Queries.Template do

  import Ecto.Query, only: [from: 2]
  alias Cog.Models.Template

  def template_source(adapter, nil, name) do
    from t in Template,
    where: is_nil(t.bundle_version_id) and
      t.adapter == ^adapter and
      t.name == ^name,
    select: t.source
  end

  def template_source(adapter, bundle_version_id, name) do
    from t in Template,
    where: t.bundle_version_id == ^bundle_version_id and
      t.adapter == ^adapter and
      t.name == ^name,
    select: t.source
  end
end
