defmodule Cog.Commands.Bundle do
  use Cog.Command.GenCommand.Base,
    bundle: Cog.Util.Misc.embedded_bundle

  alias Cog.Models.{Bundle, BundleVersion}
  alias Cog.Commands.Bundle.{List, Disable, Install}

  require Cog.Commands.Helpers, as: Helpers
  require Logger

  Helpers.usage(:root)

  @description "Manage command bundles"

  @arguments "[subcommand]"

  @subcommands %{
    "list" => "List all installed bundles (default)",
    "info <bundle>" => "Detailed information on an installed bundle",
    "enable <bundle> [<version>]" => "Enable a specific version of an installed bundle",
    "disable <bundle>" => "Disable an installed bundle",
    "versions <bundle>" => "List all installed versions for a given bundle",
    "install <bundle> [<version>]" => "Install latest or specified version of bundle from registry"
  }

  permission "manage_commands"

  rule "when command is #{Cog.Util.Misc.embedded_bundle}:bundle must have #{Cog.Util.Misc.embedded_bundle}:manage_commands"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "disable"  -> Disable.disable(req, args)
               "install"  -> Install.install(req, args)
               nil ->
                 if Helpers.flag?(req.options, "help") do
                   show_usage
                 else
                   List.handle_message(req, state)
                 end
               other ->
                 {:error, {:unknown_subcommand, other}}
             end

     case result do
       {:ok, template, data} ->
         {:reply, req.reply_to, template, data, state}
       {:ok, data} ->
         {:reply, req.reply_to, data, state}
       {:error, err} ->
         {:error, req.reply_to, error(err), state}
     end
  end

  ########################################################################

  defp error({:not_found, name}),
    do: "Bundle #{inspect name} cannot be found."
  defp error({:not_found, name, version}),
    do: "Bundle #{inspect name} with version #{inspect to_string(version)} cannot be found."
  defp error({:protected_bundle, unquote(Cog.Util.Misc.embedded_bundle)}),
    do: "Bundle #{inspect Cog.Util.Misc.embedded_bundle} is protected and cannot be disabled."
  defp error({:protected_bundle, unquote(Cog.Util.Misc.site_namespace)}),
    do: "Bundle #{inspect Cog.Util.Misc.site_namespace} is protected and cannot be enabled."
  defp error({:protected_bundle, bundle_name}),
    do: "Bundle #{inspect bundle_name} is protected and cannot be enabled or disabled."
  defp error({:invalid_version, version}),
    do: "Version #{inspect version} could not be parsed."
  defp error({:already_disabled, %BundleVersion{bundle: %Bundle{name: bundle_name}}}),
    do: "Bundle #{inspect bundle_name} is already disabled."
  defp error(:invalid_invocation),
    do: "That is not a valid invocation of the bundle command."
  defp error({:already_installed, bundle, version}),
    do: "Bundle #{inspect bundle} with version #{inspect version} already installed."
  defp error(:registry_error),
    do: "Bundle registry responded with an error."
  defp error(error),
    do: Helpers.error(error)

end
