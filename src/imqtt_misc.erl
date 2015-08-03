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