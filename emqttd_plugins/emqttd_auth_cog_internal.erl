-module(emqttd_auth_cog_internal).

-include_lib("emqttd/include/emqttd.hrl").

-behaviour(emqttd_auth_mod).

-export([init/1,
         description/0,
         check/3]).

init(_) ->
  {ok, undefined}.

description() ->
  "MQTT authentication for Cog's internal traffic".


check(_, _, _) ->
  ok.
