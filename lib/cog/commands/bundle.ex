defmodule Cog.Commands.Bundle do
  @moduledoc """

  ## Overview

  Manipulate and interrogate command bundle status.

  A bundle may be either `enabled` or `disabled`. If a bundle is
  enabled, chat invocations of commands contained within the bundle
  will be executed. If the bundle is disabled, on the other hand, no
  such commands will be run.

  Bundles may be enabled or disabled independently of whether or not
  any Relays are currently _running_ the bundles. The status of a
  bundle is managed centrally; when a Relay serving the bundle comes
  online, the status of the bundle is respected. Thus a bundle may be
  enabled, but not running on any Relays, just as it can be disabled,
  but running on _every_ Relay.

  This can be used to either quickly disable a bundle, or as the first
  step in deleting a bundle from the bot.

  Note that the `#{Cog.embedded_bundle}` bundle is a protected bundle;
  this bundle is always enabled and is in fact embedded in the bot
  itself. Core pieces of bot functionality would not work (including
  this very command itself!) if this bundle were ever disabled (though
  many functions would remain available via the REST API). As a
  result, calling either of the mutator subcommands `enable` or
  `disable` (see below) on the `#{Cog.embedded_bundle}` bundle is an
  error.

  ## Subcommands

  * `status`

          bundle status <bundle_name>

     Shows the current status of the bundle, whether `enabled` or
     `disabled`. Additionally shows which Relays (if any) are running
     the code for the bundle.

     The `enable` and `disable` subcommands (see below) also return
     this information.

     Can be called on any bundle, including `#{Cog.embedded_bundle}`.

  * `enable`

          bundle enable <bundle_name>

    Enabling a bundle allows chat commands to be routed to it. Running
    this subcommand has no effect if a bundle is already enabled.

    Cannot be used on the `#{Cog.embedded_bundle}` bundle.

  * `disable`

          bundle disable <bundle_name>

     Disabling a bundle prevents commands from being routed to it. The
     bundle is not uninstalled, and all custom rules remain
     intact. The bundle still exists, but commands in it will not be
     executed.

     A disabled bundle can be re-enabled using this the `enable`
     sub-command; see above.

     Running this subcommand has no effect if a bundle is already
     disabled.

     Cannot be used on the `#{Cog.embedded_bundle}` bundle.

  """

  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle

  alias Cog.Repo
  alias Cog.Models.Bundle

  permission "manage_commands"

  rule "when command is #{Cog.embedded_bundle}:bundle must have #{Cog.embedded_bundle}:manage_commands"

   def handle_message(req, state) do
     case run(req.args) do
       {:ok, response} ->
         {:reply, req.reply_to, "bundle", response, state}
       {:error, error} ->
         {:error, req.reply_to, error_message(error), state}
     end
   end

   defp run([action, bundle_name]) when is_binary(bundle_name)
                                    and action in ["enable", "disable"] do
     case find_bundle(bundle_name) do
       {:ok, bundle} ->
         case Bundle.Status.set(bundle, action_to_status(action)) do
           {:ok, bundle} ->
             {:ok, Bundle.Status.current(bundle)}
           {:error, :embedded_bundle}=error ->
             error
         end
       {:error, _}=error ->
         error
     end
   end
   defp run(["status", bundle_name]) when is_binary(bundle_name) do
     case find_bundle(bundle_name) do
       {:ok, bundle} ->
         {:ok, Bundle.Status.current(bundle)}
       {:error, _}=error ->
         error
     end
   end
   defp run(_) do
     {:error, :invalid_invocation}
   end

   defp action_to_status("enable"), do: :enabled
   defp action_to_status("disable"), do: :disabled

   defp find_bundle(name) do
     case Repo.get_by(Bundle, name: name) do
       nil ->
         {:error, {:not_found, name}}
       %Bundle{}=bundle ->
         {:ok, bundle}
     end
   end

   defp error_message(:embedded_bundle),
     do: "The status of the embedded bundle `#{Cog.embedded_bundle}` cannot be changed!"
   defp error_message({:not_found, name}),
     do: "The bundle `#{name}` cannot be found!"
   defp error_message(:invalid_invocation),
     do: "That is not a valid invocation of the `bundle` command"

end
