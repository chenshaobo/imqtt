%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 03. 八月 2015 17:29
%%%-------------------------------------------------------------------
-module(imqtt_db).
-author("chenshb@mpreader").


%% API
-export([init_db/0]).
-export([write/2]).
-export([read/2]).


init_db() ->
    Mod=imqtt_misc:get_db_mod(),
    Mod:init_db().


write(TableName,Record)->
    Mod=imqtt_misc:get_db_mod(),
    Mod:write(TableName,Record).

read(TableName,Key)->
    Mod=imqtt_misc:get_db_mod(),
    Mod:read(TableName,Key).


