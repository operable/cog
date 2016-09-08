defmodule Cog.Template.New do

  # This is only needed to bridge the gap while we still support the
  # old templates. Once they're gone, this can be removed.
  def default_provider,
    do: "GREENBAR_PROVIDER"

  def extension,
    do: ".greenbar"

  def template_dir(:common),
    do: Path.join([:code.priv_dir(:cog), "templates", "common"])
  def template_dir(:embedded),
    do: Path.join([:code.priv_dir(:cog), "templates", "embedded"])

  # Output from pipelines will be wrapped in an envelope for template
  # processing.
  def with_envelope(output),
    do: %{"results" => List.wrap(output)}

end
