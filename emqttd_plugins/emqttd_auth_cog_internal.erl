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


check(Client, Password, _) ->
  case 'Elixir.Cog.BusCredentials':'connect_allowed?'(Client, Password) of
    true ->
      ok;
    false ->
      {error, bad_credentials}
  end.
