%%%-------------------------------------------------------------------
%%% @author chenshb@mpreader
%%% @copyright (C) 2015, <MPR Reader>
%%% @doc
%%%
%%% @end
%%% Created : 03. 八月 2015 19:05
%%%-------------------------------------------------------------------
-author("chenshb@mpreader").

-record(t_user,{user_name,password,subscribes=[]}).


-define(MQTT_TABLES,[
    {t_user,t_user,record_info(fields,t_user)}
]).

