%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 31. 七月 2015 10:10
%%%-------------------------------------------------------------------
-module(imqtt_misc).
-author("chenshb@mpreader").

%% API
-export([now_second/0]).
-export([to_atom/1]).
-export([to_bin/1]).

-export([get_db_mod/0]).

now_second()->
    {A,B,_}=erlang:now(),
    A*1000000 +B.


%%Be careful atom table crash erlang vm.
to_atom(Atom) when is_atom(Atom)->
    Atom;
to_atom(List) when is_list(List)->
    erlang:list_to_atom(List);
to_atom(Bin) when is_binary(Bin)->
    erlang:binary_to_atom(Bin,utf8).

to_bin(Atom ) when is_atom(Atom)->
    erlang:atom_to_binary(Atom,utf8);
to_bin(List) when is_list(List)->
    erlang:list_to_binary(List);
to_bin(Int) when is_integer(Int)->
    erlang:integer_to_binary(Int);
to_bin(Bin) when is_binary(Bin)->
    Bin.

get_db_mod()->
    case application:get_env(imqtt,db_mod) of
        {ok,Mod}->
            Mod;
        _ ->
            imqtt_db_mnesia
    end.