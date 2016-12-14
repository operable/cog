defmodule Cog.Commands.Bundle do
  alias Cog.Commands.Helpers
  alias Cog.Models.{Bundle, BundleVersion}
  alias Cog.Util.Misc

  def error({:not_found, name}),
    do: "Bundle #{inspect name} cannot be found."
  def error({:not_found, name, version}),
    do: "Bundle #{inspect name} with version #{inspect to_string(version)} cannot be found."
  def error({:protected_bundle, unquote(Misc.embedded_bundle)}),
    do: "Bundle #{inspect Misc.embedded_bundle} is protected and cannot be disabled."
  def error({:protected_bundle, unquote(Misc.site_namespace)}),
    do: "Bundle #{inspect Misc.site_namespace} is protected and cannot be enabled."
  def error({:protected_bundle, bundle_name}),
    do: "Bundle #{inspect bundle_name} is protected and cannot be enabled or disabled."
  def error({:invalid_version, version}),
    do: "Version #{inspect version} could not be parsed."
  def error({:already_disabled, %BundleVersion{bundle: %Bundle{name: bundle_name}}}),
    do: "Bundle #{inspect bundle_name} is already disabled."
  def error(:invalid_invocation),
    do: "That is not a valid invocation of the bundle command."
  def error({:already_installed, bundle, version}),
    do: "Bundle #{inspect bundle} with version #{inspect version} already installed."
  def error(:registry_error),
    do: "Bundle registry responded with an error."
  def error(error),
    do: Helpers.error(error)
end
