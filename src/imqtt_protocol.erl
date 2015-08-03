%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 29. 七月 2015 19:04
%%%-------------------------------------------------------------------
-module(imqtt_protocol).
-author("chenshb@mpreader").
-behaviour(ranch_protocol).
%% API
-export([start_link/4]).
-export([init/5]).
-export([loop/1]).
-export([system_continue/3]).
-export([system_terminate/4,system_code_change/4]).

-include("mqtt.hrl").

-record(will, {will_flag, will_topic, will_qos, will_message, will_retain}).
-record(mqtt, {parent,socket, transport, client_id, username, password, clean_session, will = #will{}, last_ping, keep_alive,subscribes=[]}).

-record(mqtt_message, {type, dup, qos, retain, length, variable_header, payload}).

-define(TRANSPORT, ranch_tcp).

start_link(Ref, Socket, Transport, ProtocolOptions) ->
    Pid = proc_lib:spawn_link(?MODULE, init, [Ref, Socket, Transport, ProtocolOptions,self()]),
    {ok, Pid}.


init(Ref, Socket, Transport, _ProtocolOptions,Parent) ->
    ranch:accept_ack(Ref),
    loop(#mqtt{parent = Parent,socket = Socket, transport = Transport}).


loop(#mqtt{parent=Parent,socket = Socket} = S) ->
    inet:setopts(Socket, [{active, once}]),
    receive
        {tcp, Socket, <<?DISCONNECT:4, 0:4, 0:8>>} ->
            lager:info("client disconnect  exit"),
            close(S);
        {tcp, Socket, Packet} ->
            lager:info("~p", [Packet]),
            NewS = handle_msg(Packet, S),
            lager:info("NewState:~p", [NewS]),
            loop(NewS);
        {tcp_closed, Socket} ->
            lager:error("tcp close exit"),
            close(S);
        check_alive ->
            KeepAlive = S#mqtt.keep_alive,
            LastPing = S#mqtt.last_ping,
            Now = imqtt_misc:now_second(),
            lager:info("Now-LastPing=~p;KeepAlive:~p", [Now - LastPing, KeepAlive]),
            case Now - LastPing >= KeepAlive of
                true ->
                    lager:error("ping timeout :exit"),
                    close(S);
                false ->
                    check_alive(KeepAlive),
                    loop(S)
            end;
        {system, From, Request} ->
            sys:handle_system_msg(Request, From, Parent, ?MODULE, [],
                {state, Parent})
    end.




system_continue(_, _, {state, Parent}) ->
    loop(Parent).


system_terminate(Reason, _, _, _) ->
    exit(Reason).
system_code_change(Misc, _, _, _) ->
    lager:info("~p",[Misc]),
    {ok, Misc}.


handle_msg(<<MsgType:4, Dup:1, Qos:2, Retain:1, Rest/binary>>, State) ->
    {Length, Remain} = parse_length(Rest, 1, 0),
    MSG =
        #mqtt_message{
            type = MsgType,
            dup = Dup,
            qos = Qos,
            retain = Retain,
            length = Length
        },

    handle_type(MSG, Remain, State#mqtt{last_ping = imqtt_misc:now_second()});

handle_msg(_R, _S) ->
    lager:info("receive :~p", [_R]), _S.


handle_type(#mqtt_message{type = ?CONNECT}, Remain, State) ->
    %VARIABLE HEADER
    %proto_name_length 2 byte
    %proto_name
    %proto_ver  1byte
    %connect flag  usernameflag  passwordflag willretain willqos willflag cleansession
    %keep_alive 2byte
    %willtopic length
    %will topic
    %willmessage length
    %will message
    %username length
    %username
    %password length
    %password
    <<ProLen:16, Proname:ProLen/binary, _ProVer:8, ConnectFlag:8/bits, KeepAlive:16, Remain1/binary>> = Remain,
    <<HadUserName:1, HadPassword:1, WillRetain:1, WillQos:2, WillFlag:1, CleanSession:1, _:1>> = ConnectFlag,
    lager:info("~p", [{HadUserName, HadPassword, WillRetain, WillQos, WillFlag, CleanSession}]),
    lager:info("Protoname:~p~nConnectFlag:~p~nkeepalive:~p~nremain:~p~n", [Proname, ConnectFlag, KeepAlive, Remain1]),
    {ClientID, Remain2} = get_content(Remain1),
    erlang:register(erlang:binary_to_atom(ClientID,utf8),self()),
    {Topic, MSG, Remain5} =
        case WillFlag of
            ?WillFlag ->
                {WillTopic, Remain3} = get_content(Remain2),
                {WillMsg, Remain4} = get_content(Remain3),
                {WillTopic, WillMsg, Remain4};
            _ ->
                {"", "", Remain2}
        end,
    {UserName, Remain6} = ?IF(HadUserName =:= ?SET, get_content(Remain5), {"", Remain5}),
    {Password, _Remain7} = ?IF(HadPassword =:= ?SET, get_content(Remain6), {"", Remain6}),

    Will = #will{will_flag = WillFlag, will_topic = Topic, will_message = MSG, will_qos = WillQos, will_retain = WillRetain},

    send(State#mqtt.socket, <<?CONNACK:4, 0:4, 1:8, 0>>),
    MaxKeepAlive = erlang:trunc(KeepAlive * 1.5) + 1,
    check_alive(MaxKeepAlive),
    State#mqtt{client_id = ClientID, keep_alive = MaxKeepAlive, username = UserName, password = Password, clean_session = CleanSession, will = Will};

handle_type(#mqtt_message{type = ?PINGREQ}, _Remain, State) ->
%%     send(State#mqtt.socket, <<?PINGRESP:4, 0:4, 0:8>>),
    State#mqtt{last_ping = imqtt_misc:now_second()};

handle_type(#mqtt_message{type = ?PUBLISH} = Opt, Remain, State) ->
    %%VARIABLE HEADER
    %topicname length 2bytes
    %topicname
    %messageid 2bytes
    %%PLAYLOAD
    %message data
    lager:info("~p", [Remain]),
    {TopicName, Remain1} = get_content(Remain),
    {MessageID, MSG} =
        case Opt#mqtt_message.qos of
            ?QoS0 ->
                {undefined, Remain1};
            _ ->
                <<MessageIDtmp:16, Remain2/binary>> = Remain1,
                {MessageIDtmp, Remain2}
        end,
    lager:info("TopicName:~p~nMessageID:~p~nMsg:~p", [TopicName, MessageID, MSG]),
    ok = route_message(TopicName, Opt, MessageID, MSG),
    publish_response(Opt#mqtt_message.qos, MessageID, State#mqtt.socket),
    State;
handle_type(#mqtt_message{type=?SUBSCRIBE},Remain,State)->
    <<MessageID:16,Remain1/binary>> = Remain,
    Subs=subscribe_message(Remain1,State#mqtt.client_id,State#mqtt.subscribes),
    send(State#mqtt.socket,<<?SUBACK:4,0:4,MessageID:16>>),
    State#mqtt{subscribes = Subs};
handle_type(#mqtt_message{type = ?UNSUBSCRIBE},Remain,State)->
    <<MessageID:16,Remain1/binary>> = Remain,
    NewSubs=unsubscribe_message(Remain1,State#mqtt.client_id,State#mqtt.subscribes),

    send(State#mqtt.socket,<<?SUBACK:4,0:4,MessageID:16>>),
    State#mqtt{subscribes = NewSubs}.

unsubscribe_message(<<>>,_ClientID,Acc)->
    Acc;
unsubscribe_message(Bin,ClientID,Acc)->
    <<ProLen:16,TopicName:ProLen/binary,Remain/binary>>=Bin,
    TopicNameAtom=imqtt_misc:to_atom(TopicName),
    case lists:member(TopicNameAtom,Acc) of
        true->
            imqtt_pubsub:unsub(TopicNameAtom,ClientID),
            lager:info("unsubscribe:~p",[TopicNameAtom]),
            unsubscribe_message(Remain,ClientID,lists:delete(TopicNameAtom,Acc));
        _ ->
            unsubscribe_message(Remain,ClientID,Acc)
    end.


subscribe_message(<<>>,_ClientID,Acc)->
    Acc;
subscribe_message(Bin,ClientID,Acc)->
    <<ProLen:16,TopicName:ProLen/binary,QOS:8,Remain/binary>>=Bin,
    TopicName,QOS,
    %%LIMIT TOPIC NUMBER?
    TopicNameAtom=imqtt_misc:to_atom(TopicName),
    case lists:member(TopicNameAtom,Acc) of
        true ->
            subscribe_message(Remain,ClientID,Acc);
        _ ->
            case whereis(TopicNameAtom) of
                undefined ->
                    lager:info("not start :~p",[TopicNameAtom]),
                    imqtt_sup:start_child(TopicNameAtom);
                _ ->
                    next
            end,
            imqtt_pubsub:sub(TopicNameAtom,ClientID),
            lager:info("subscribe:~p",[TopicName]),
            subscribe_message(Remain,ClientID,[TopicNameAtom|Acc])
    end.



parse_length(_Binary, Index, _Length) when Index > 4 ->
    erlang:throw({error, max_length});
parse_length(<<0:1, Length:7, Reamin/binary>>, Index, LengthAcc) ->
    {Index * Length + LengthAcc, Reamin};
parse_length(<<1:1, Length:7, Remain/binary>>, Index, LengthAcc) ->
    parse_length(Remain, Index + 1, LengthAcc + Index * Length).


get_content(Bin) ->
     case Bin of
         <<ProLen:16,Content:ProLen/binary>>->
             {Content,<<>>};
         <<ProLen:16, Content:ProLen/binary, Remain/binary>>->
             {Content, Remain}
     end.

%% get_state()->
%%     erlang:get(mqtt_state).
%%
%% set_state(Val)->
%%     erlang:put(mqtt_state,Val).

send(Socket, Bin) ->
    ?TRANSPORT:send(Socket, Bin).

check_alive(KeepAlive) ->
    erlang:send_after(KeepAlive * 1000, self(), check_alive).

route_message(TopicName, Opt, MessageID, MSG) ->
    TopicName, Opt, MessageID, MSG,
    ok.

publish_response(?QoS0, _Message,_Socket) ->
    ignore;
publish_response(?QoS1, MessageID, Socket) ->
    send(Socket, <<?PUBACK:4, 0:4, 2:8, MessageID/binary>>);
publish_response(?QoS2,MessageID,Socket)->
    send(Socket,<<?PUBREC:4, 0:4, 2:8, MessageID/binary>>).

close(#mqtt{socket = Socket,subscribes = Subs,client_id = ClientID})->
    [imqtt_pubsub:offline(TopicName,ClientID)|| TopicName <-Subs],
    ?TRANSPORT:close(Socket).