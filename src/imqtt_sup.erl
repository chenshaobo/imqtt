%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 29. 七月 2015 19:03
%%%-------------------------------------------------------------------
-module(imqtt_sup).
-author("chenshb@mpreader").

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).
-export([start_child/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).


start_child(Name)->
    supervisor:start_child(?SERVER,[Name]).
%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
        MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
        [ChildSpec :: supervisor:child_spec()]
    }} |
    ignore |
    {error, Reason :: term()}).
init([]) ->
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 50,
    MaxSecondsBetweenRestarts = 10,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    Pubsub={imqtt_pubsub,{imqtt_pubsub,start_link,[]},permanent,1000,worker,[imqtt_pubsub]},
    {ok, {SupFlags, [Pubsub]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
