defmodule Cog.Integration.Helpers do
  def render_template(template_name, data) when is_list(data),
    do: Enum.map_join(data, "\n", &(render_template(template_name, &1)))
  def render_template(template_name, data) do
    template = Cog.Repo.get_by(Cog.Models.Template, %{name: template_name, adapter: "test"})
    FuManchu.render!(template.source, data)
  end
end
