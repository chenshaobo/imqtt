%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 28. 七月 2015 17:27
%%%-------------------------------------------------------------------
-author("chenshb@mpreader").


-define(CONNECT,      1).
-define(CONNACK,      2).
-define(PUBLISH,      3).
-define(PUBACK,       4).
-define(PUBREC,       5).
-define(PUBREL,       6).
-define(PUBCOMP,      7).
-define(SUBSCRIBE,    8).
-define(SUBACK,       9).
-define(UNSUBSCRIBE, 10).
-define(UNSUBACK,    11).
-define(PINGREQ,     12).
-define(PINGRESP,    13).
-define(DISCONNECT,  14).


-define(QoS0,0).
-define(QoS1,1).
-define(QoS2,2).

-define(WILL_FLAG,1).
-define(SET,1).
-define(NOT_SET,0).

-define(RETAIN_SET,1).

-define(CLEAN_SESSION_TRUE,1).
-define(CLEAN_SESSION_FALSE,0).

-define(CARRY_BIT,16#80).
-define(MAX_LENGTH,268435455).


%% %%FIXED HEADER(固定头部)
%% %%        7   6   5   4      3     2   1      0
%% byte1     message_type   dupflag   QoSLV   RETAIN
%% byte2     Remaining Length
%% %%Variable HEADER(可变头部)
%%           Variable header
%%             ....
%%           MSG

-define(IF(CON,A,B),case CON of true->A ; false->B end).


-record(will, {will_flag, will_topic, will_qos, will_message, will_retain}).
-record(mqtt, {parent, socket, transport, client_id, username, password, clean_session, will = #will{}, last_ping, keep_alive, subscribes = []}).

-record(mqtt_message, {type, dup, qos, retain, length, variable_header, payload}).