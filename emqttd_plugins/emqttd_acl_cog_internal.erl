-module(emqttd_acl_cog_internal).

-behaviour(emqttd_acl_mod).

-include_lib("emqttd/include/emqttd.hrl").

-export([init/1,
         check_acl/2,
         reload_acl/1,
         description/0]).

init(_) ->
  {ok, []}.

check_acl({_Client, _PubSub, _Topic}, _State) ->
  allow.

reload_acl(_) ->
  ok.

description() ->
  "MQTT authorization for Cog's internal traffic".

