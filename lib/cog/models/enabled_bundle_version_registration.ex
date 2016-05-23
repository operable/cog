defmodule Cog.Models.EnabledBundleVersionRegistration do
  @moduledoc """
  Association solely for providing the `enabled_version` association
  on a `Bundle`. Shouldn't be used for anything else.
  """
  use Cog.Model

  @primary_key false
  schema "enabled_bundle_version_view" do
    belongs_to :bundle, Cog.Models.Bundle
    belongs_to :bundle_version, Cog.Models.BundleVersion
  end

end
