%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 05. 八月 2015 9:33
%%%-------------------------------------------------------------------
-module(imqtt_db_mnesia).
-author("chenshb@mpreader").

-include("imqtt_db.hrl").
%% API
-export([init_db/0]).
-export([write/2]).
-export([read/2]).

init_db() ->
    mnesia:start(),
    mnesia:create_schema([node()]),
    [begin
         R = mnesia:create_table(Tab, [{disc_copies, [erlang:node()]}, {record_name, Rec}, {type, set}, {attributes, Fields}]),
         lager:info("~p", [R])
     end || {Tab, Rec, Fields} <- ?MQTT_TABLES].


write(Table,Record)->
    mnesia:dirty_write(Table,Record).

read(Table,Record)->
    mnesia:dirty_read(Table,Record).