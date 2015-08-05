%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%    每个topic一个server处理还是n个worker轮流处理topic合适呢
%%% @end
%%% Created : 03. 八月 2015 15:08
%%%-------------------------------------------------------------------
-module(imqtt_pubsub).
-author("chenshb@mpreader").

-behaviour(gen_server).

%% API
-export([start_link/1]).
-include("imqtt.hrl").
-include("imqtt_db.hrl").

%% -include_lib("eunit/include/eunit.hrl").
%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).

-export([sub/2]).
-export([offline/2]).
-export([unsub/2]).
-export([pub/2]).

-export([megre_len/1]).

-define(SERVER, ?MODULE).

-record(state, {topicname, subscribers = [], message_id = 0}).

%%%===================================================================
%%% API
%%%===================================================================
sub(TopicName, ClientID) ->
    gen_server:call(imqtt_misc:to_atom(TopicName), {sub, ClientID}).

offline(TopicName, ClientID) ->
    erlang:send(imqtt_misc:to_atom(TopicName), {offline, ClientID}).

unsub(TopicName, ClientID) ->
    gen_server:call(imqtt_misc:to_atom(TopicName), {unsub, ClientID}).

pub(TopicName, Msg) ->
    erlang:send(imqtt_misc:to_atom(TopicName), {pub, Msg}).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------

start_link(Name) ->
    gen_server:start_link({local, imqtt_misc:to_atom(Name)}, ?MODULE, [Name], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================


init([Name]) ->
    {ok, #state{topicname = Name}}.

handle_call({sub, Client}, _From, State) ->
    Subscribers = State#state.subscribers,
    NewSubscribers =
        case lists:member(Client, Subscribers) of
            true ->
                Subscribers;
            _ ->
                [Client | Subscribers]
        end,
    {reply, ok, State#state{subscribers = NewSubscribers}};
handle_call({unsub, Client}, _From, State) ->
    Subscribers = State#state.subscribers,
    {reply, ok, State#state{subscribers = do_unsub(Client, Subscribers)}};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info({pub, {MessageOpt, Message}}, State) ->
    Subscribers = State#state.subscribers,

    Dup = MessageOpt#mqtt_message.dup,
    Qos = MessageOpt#mqtt_message.qos,
    Retain = MessageOpt#mqtt_message.retain,
    TopicName = imqtt_misc:to_bin(State#state.topicname),
    TopicSize = erlang:byte_size(TopicName),
    MessageID = State#state.message_id,

    Payload = case Qos of
                  ?QoS0 ->
                      <<TopicSize:16, TopicName/binary, Message/binary>>;
                  _ ->
                      <<TopicSize:16, TopicName/binary, MessageID:16, Message/binary>>
              end,
    PayloadLen = erlang:byte_size(Payload),

    RemainLength = megre_len(PayloadLen),
    SendMessage = <<?PUBLISH:4, Dup:1, Qos:2, Retain:1, RemainLength/binary, Payload/binary>>,
    [begin
         catch erlang:send(Client, {message, SendMessage})
     end || Client <- Subscribers],
    {noreply, State#state{message_id = MessageID + 1}};
handle_info({offline,ClientID},State)->
    {noreply,State#state{subscribers =  do_unsub(ClientID,State#state.subscribers)}}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
do_unsub(Client, Subscribers) ->
    lists:delete(Client, Subscribers).

%% megre_len_test()->
%%     [?assert(megre_len(128)=:= << 16#8001 >>),
%%         ?assert(megre_len(16384)=:= << 16#808001>>),
%%         ?assert(megre_len(2097151)=:= <<16#FFFF7F>>),
%%         ?assert(megre_len(2097152)=:= <<16#80808001>>),
%%         ?assert(megre_len(268435455) =:= << 16#FFFFFF7F>>)].
megre_len(Len) ->
    Mod = Len rem ?CARRY_BIT,
    Div = Len div ?CARRY_BIT,
    megre_len(Div, Mod, <<>>).
megre_len(Div, Mod, Acc) when Div > 0 ->
    Div1 = Div div ?CARRY_BIT,
    Mod1 = Div rem ?CARRY_BIT,
    Val = Mod bor 16#80,
    megre_len(Div1, Mod1, <<Acc/binary, Val>>);
megre_len(_Div, Mod, Acc) ->
    B = <<Acc/binary, Mod:8>>,
    B.
