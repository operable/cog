-module(emqttd_acl_cog_internal).

-behaviour(emqttd_acl_mod).

-include_lib("emqttd/include/emqttd.hrl").

-export([init/1,
         check_acl/2,
         reload_acl/1,
         description/0]).

init(_) ->
  {ok, []}.

%% Publish is always allowed
check_acl({_Client, publish, _}, _State) ->
  allow;
check_acl({Client, subscribe, Topic}, _State) ->
  case 'Elixir.Cog.BusCredentials':'subscription_allowed?'(Client, Topic) of
    false ->
      deny;
    true ->
      allow
  end.

reload_acl(_) ->
  ok.

description() ->
  "MQTT authorization for Cog's internal traffic".

