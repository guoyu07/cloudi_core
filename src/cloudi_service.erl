%-*-Mode:erlang;coding:utf-8;tab-width:4;c-basic-offset:4;indent-tabs-mode:()-*-
% ex: set ft=erlang fenc=utf-8 sts=4 ts=4 sw=4 et:
%%%
%%%------------------------------------------------------------------------
%%% @doc
%%% ==CloudI Internal Service Behavior==
%%% The interface which all internal services must implement.
%%% ```
%%% The user module should export:
%%%
%%%   cloudi_service_init(Args, Prefix, Dispatcher)  
%%%    ==> {ok, State}
%%%        {stop, Reason}
%%%        {stop, Reason, State}
%%%               State = undefined, if not returned
%%%               Reason = restart | shutdown | Term, terminate(State) is called
%%%
%%%   cloudi_service_handle_request(Type, Name, Pattern,
%%%                                 RequestInfo, Request, Timeout, Priority,
%%%                                 TransId, Pid, State, Dispatcher)
%%%    ==> {reply, Response, NewState}
%%%        {reply, ResponseInfo, Response, NewState}
%%%        {forward, NextName, NextRequestInfo, NextRequest, NewState}
%%%        {forward, NextName, NextRequestInfo, NextRequest,
%%%         NextTimeout, NextPriority, NewState}
%%%        {noreply, NewState}
%%%        {stop, Reason, NewState}  
%%%               Reason = restart | shutdown | Term, terminate(State) is called
%%%
%%%   cloudi_service_handle_info(Request, State, Dispatcher)
%%%
%%%    ==> {noreply, State}
%%%        {stop, Reason, NewState} 
%%%               Reason = restart | shutdown | Term, terminate(State) is called
%%%
%%%   cloudi_service_terminate(Reason, State) Let the user module clean up
%%%        always called when the service terminates
%%%
%%%    ==> ok
%%%
%%%
%%% The work flow (of the service) can be described as follows:
%%%
%%%    User module                                          Generic
%%%    -----------                                          -------
%%%    cloudi_service_init              <-----              .
%%%
%%%                                                         loop
%%%    cloudi_service_handle_request    <-----              .
%%%                                     ----->              reply
%%%
%%%    cloudi_service_handle_info       <-----              .
%%%
%%%    cloudi_service_terminate         <-----              .
%%%
%%% '''
%%% @end
%%%
%%% BSD LICENSE
%%% 
%%% Copyright (c) 2011-2014, Michael Truog <mjtruog at gmail dot com>
%%% All rights reserved.
%%% 
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%% 
%%%     * Redistributions of source code must retain the above copyright
%%%       notice, this list of conditions and the following disclaimer.
%%%     * Redistributions in binary form must reproduce the above copyright
%%%       notice, this list of conditions and the following disclaimer in
%%%       the documentation and/or other materials provided with the
%%%       distribution.
%%%     * All advertising materials mentioning features or use of this
%%%       software must display the following acknowledgment:
%%%         This product includes software developed by Michael Truog
%%%     * The name of the author may not be used to endorse or promote
%%%       products derived from this software without specific prior
%%%       written permission
%%% 
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
%%% CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
%%% INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
%%% OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
%%% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
%%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
%%% DAMAGE.
%%%
%%% @author Michael Truog <mjtruog [at] gmail (dot) com>
%%% @copyright 2011-2014 Michael Truog
%%% @version 1.3.3 {@date} {@time}
%%%------------------------------------------------------------------------

-module(cloudi_service).
-author('mjtruog [at] gmail (dot) com').

%% behavior interface
-export([process_index/1,
         process_count/1,
         process_count_max/1,
         process_count_min/1,
         self/1,
         dispatcher/1,
         subscribe/2,
         unsubscribe/2,
         get_pid/2,
         get_pid/3,
         get_pids/2,
         get_pids/3,
         send_async/3,
         send_async/4,
         send_async/5,
         send_async/6,
         send_async/7,
         send_async_active/3,
         send_async_active/4,
         send_async_active/5,
         send_async_active/6,
         send_async_active/7,
         send_async_active/8,
         send_async_passive/3,
         send_async_passive/4,
         send_async_passive/5,
         send_async_passive/6,
         send_async_passive/7,
         send_sync/3,
         send_sync/4,
         send_sync/5,
         send_sync/6,
         send_sync/7,
         mcast_async/3,
         mcast_async/4,
         mcast_async/6,
         mcast_async_active/3,
         mcast_async_active/4,
         mcast_async_active/6,
         mcast_async_passive/3,
         mcast_async_passive/4,
         mcast_async_passive/6,
         forward/9,
         forward_async/8,
         forward_sync/8,
         return/2,
         return/3,
         return/9,
         return_async/8,
         return_sync/8,
         return_nothrow/9,
         recv_async/1,
         recv_async/2,
         recv_async/3,
         recv_async/4,
         recv_asyncs/2,
         recv_asyncs/3,
         recv_asyncs/4,
         % service configuration
         prefix/1,
         timeout_async/1,
         timeout_sync/1,
         timeout_max/1,
         priority_default/1,
         destination_refresh_immediate/1,
         destination_refresh_lazy/1,
         source_subscriptions/2,
         context_options/1,
         trans_id/1,
         % deprecated, moved to the cloudi_environment module
         environment_lookup/0,
         environment_transform/1,
         environment_transform/2,
         % deprecated, moved to the cloudi_service_name module
         service_name_new/2,
         service_name_new/4,
         service_name_parse/2,
         service_name_parse_with_suffix/2,
         % deprecated, moved to the cloudi_request module
         request_http_qs_parse/1,
         % deprecated, moved to the cloudi_request_info module
         request_info_key_value_new/1,
         request_info_key_value_parse/1,
         % deprecated, moved to the cloudi_key_value module
         key_value_erase/2,
         key_value_find/2,
         key_value_store/3,
         % functions to trigger edoc, until -callback works with edoc
         'Module:cloudi_service_init'/3,
         'Module:cloudi_service_handle_request'/11,
         'Module:cloudi_service_handle_info'/3,
         'Module:cloudi_service_terminate'/2]).

-include("cloudi_constants.hrl").

-type request_type() :: 'send_async' | 'send_sync'.
-type service_name() :: cloudi:service_name().
-type service_name_pattern() :: cloudi:service_name_pattern().
-type request_info() :: cloudi:request_info().
-type request() :: cloudi:request().
-type response_info() :: cloudi:response_info().
-type response() :: cloudi:response().
-type timeout_value_milliseconds() :: cloudi:timeout_value_milliseconds().
-type timeout_milliseconds() :: cloudi:timeout_milliseconds().
-type priority_value() :: cloudi:priority_value().
-type priority() :: cloudi:priority().
-type trans_id() :: cloudi:trans_id(). % version 1 UUID
-type pattern_pid() :: cloudi:pattern_pid().
-export_type([request_type/0,
              service_name/0,
              service_name_pattern/0,
              request_info/0, request/0,
              response_info/0, response/0,
              timeout_value_milliseconds/0,
              timeout_milliseconds/0,
              priority_value/0,
              priority/0,
              trans_id/0,
              pattern_pid/0]).

-type dispatcher() :: pid().
-type source() :: pid().
-export_type([dispatcher/0,
              source/0]).

-type error_reason() :: timeout.
-type error_reason_sync() :: error_reason() | invalid_state.
-export_type([error_reason/0,
              error_reason_sync/0]).

% for cloudi_service_api:aspect_request_after_internal() and
% cloudi_service_api:aspect_request_after_external() and
-type request_result() ::
    {reply, ResponseInfo :: response_info(), Response :: response()} |
    {forward, NextName :: service_name(),
     NextRequestInfo :: request_info(), NextRequest :: request(),
     NextTimeout :: timeout_value_milliseconds(),
     NextPriority :: priority_value()} |
    noreply.
-export_type([request_result/0]).

% used for accessing RequestInfo data
-type key_values(Key, Value) :: cloudi_key_value:key_values(Key, Value).
-type key_values() :: cloudi_key_value:key_values().
-export_type([key_values/2,
              key_values/0]).

-define(CATCH_TIMEOUT(F),
        try F catch exit:{timeout, _} -> {error, timeout} end).

%%%------------------------------------------------------------------------
%%% Callback functions from behavior
%%%------------------------------------------------------------------------

-callback cloudi_service_init(Args :: list(),
                              Prefix :: service_name_pattern(),
                              Dispatcher :: dispatcher()) ->
    {ok, State :: any()} |
    {stop, Reason :: any()} |
    {stop, Reason :: any(), State :: any()}.

-callback cloudi_service_handle_request(Type :: request_type(),
                                        Name :: service_name(),
                                        Pattern :: service_name_pattern(),
                                        RequestInfo :: request_info(),
                                        Request :: request(),
                                        Timeout :: timeout_value_milliseconds(),
                                        Priority :: priority_value(),
                                        TransId :: trans_id(),
                                        Source :: source(),
                                        State :: any(),
                                        Dispatcher :: dispatcher()) ->
    {reply, Response :: response(), NewState :: any()} |
    {reply, ResponseInfo :: response_info(), Response :: response(),
     NewState :: any()} |
    {forward, NextName :: service_name(),
     NextRequestInfo :: request_info(), NextRequest :: request(),
     NewState :: any()} |
    {forward, NextName :: service_name(),
     NextRequestInfo :: request_info(), NextRequest :: request(),
     NextTimeout :: timeout_value_milliseconds(),
     NextPriority :: priority_value(), NewState :: any()} |
    {noreply, NewState :: any()} |
    {stop, Reason :: any(), NewState :: any()}.

-callback cloudi_service_handle_info(Request :: any(),
                                     State :: any(),
                                     Dispatcher :: dispatcher()) ->
    {noreply, NewState :: any()} |
    {stop, Reason :: any(), NewState :: any()}.

-callback cloudi_service_terminate(Reason :: any(),
                                   State :: any()) ->
    ok.

%%%------------------------------------------------------------------------
%%% Behavior interface functions
%%%------------------------------------------------------------------------

%%-------------------------------------------------------------------------
%% @doc
%% ===Return the 0-based index of this instance of the service.===
%% The configuration of the service defined how many instances should exist.
%% @end
%%-------------------------------------------------------------------------

-spec process_index(Dispatcher :: dispatcher()) ->
    ProcessIndex :: non_neg_integer().

process_index(Dispatcher) ->
    gen_server:call(Dispatcher, process_index, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return the initial process count of this instance of the service.===
%% The configuration of the service defined how many instances should exist.
%% @end
%%-------------------------------------------------------------------------

-spec process_count(Dispatcher :: dispatcher()) ->
    ProcessCount :: pos_integer().

process_count(Dispatcher) ->
    gen_server:call(Dispatcher, process_count, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return the process count maximum of this instance of the service.===
%% This will be the same as the process_count, unless count_process_dynamic
%% configuration provides a maximum that is greater than the process_count.
%% @end
%%-------------------------------------------------------------------------

-spec process_count_max(Dispatcher :: dispatcher()) ->
    ProcessCountMax :: pos_integer().

process_count_max(Dispatcher) ->
    gen_server:call(Dispatcher, process_count_max, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return the process count minimum of this instance of the service.===
%% This will be the same as the process_count, unless count_process_dynamic
%% configuration provides a minimum that is less than the process_count.
%% @end
%%-------------------------------------------------------------------------

-spec process_count_min(Dispatcher :: dispatcher()) ->
    ProcessCountMin :: pos_integer().

process_count_min(Dispatcher) ->
    gen_server:call(Dispatcher, process_count_min, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return the Erlang pid representing the service.===
%% @end
%%-------------------------------------------------------------------------

-spec self(Dispatcher :: dispatcher()) ->
    Self :: pid().

self(Dispatcher) ->
    gen_server:call(Dispatcher, self, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return the Erlang pid representing the service sender.===
%% Use when the Dispatcher is stored and used after the current
%% cloudi_service callback has returned.  This is only necessary when
%% storing the dispatcher within the cloudi_service_init/3 callback,
%% for use in a different callback.
%% @end
%%-------------------------------------------------------------------------

-spec dispatcher(Dispatcher :: dispatcher()) ->
    NewDispatcher :: pid().

dispatcher(Dispatcher) ->
    gen_server:call(Dispatcher, dispatcher, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Subscribe to a service name pattern.===
%% @end
%%-------------------------------------------------------------------------

-spec subscribe(Dispatcher :: dispatcher(),
                Pattern :: service_name_pattern()) ->
    ok | error.

subscribe(Dispatcher, Pattern)
    when is_pid(Dispatcher), is_list(Pattern) ->
    gen_server:call(Dispatcher, {'subscribe', Pattern}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Unsubscribe from a service name pattern.===
%% @end
%%-------------------------------------------------------------------------

-spec unsubscribe(Dispatcher :: dispatcher(),
                  Pattern :: service_name_pattern()) ->
    ok | error.

unsubscribe(Dispatcher, Pattern)
    when is_pid(Dispatcher), is_list(Pattern) ->
    gen_server:call(Dispatcher, {'unsubscribe', Pattern}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Get a service destination based on a service name.===
%% @end
%%-------------------------------------------------------------------------

-spec get_pid(Dispatcher :: dispatcher(),
              Name :: service_name()) ->
    {ok, PatternPid :: pattern_pid()} |
    {error, Reason :: error_reason()}.

get_pid(Dispatcher, Name)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'get_pid', Name}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Get a service destination based on a service name.===
%% @end
%%-------------------------------------------------------------------------

-spec get_pid(Dispatcher :: dispatcher(),
              Name :: service_name(),
              Timeout :: timeout_milliseconds()) ->
    {ok, PatternPid :: pattern_pid()} |
    {error, Reason :: error_reason()}.

get_pid(Dispatcher, Name, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'get_pid', Name}, infinity);

get_pid(Dispatcher, Name, immediate) ->
    get_pid(Dispatcher, Name, ?SEND_SYNC_INTERVAL - 1);

get_pid(Dispatcher, Name, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'get_pid', Name,
                                    Timeout}, Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Get all service destinations based on a service name.===
%% @end
%%-------------------------------------------------------------------------

-spec get_pids(Dispatcher :: dispatcher(),
               Name :: service_name()) ->
    {ok, PatternPids :: list(pattern_pid())} |
    {error, Reason :: error_reason()}.

get_pids(Dispatcher, Name)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'get_pids', Name}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Get a service destination based on a service name.===
%% @end
%%-------------------------------------------------------------------------

-spec get_pids(Dispatcher :: dispatcher(),
               Name :: service_name(),
               Timeout :: timeout_milliseconds()) ->
    {ok, PatternPids :: list(pattern_pid())} |
    {error, Reason :: error_reason()}.

get_pids(Dispatcher, Name, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'get_pids', Name}, infinity);

get_pids(Dispatcher, Name, immediate) ->
    get_pid(Dispatcher, Name, ?SEND_SYNC_INTERVAL - 1);

get_pids(Dispatcher, Name, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'get_pids', Name,
                                    Timeout}, Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_async(Dispatcher :: dispatcher(),
                 Name :: service_name(),
                 Request :: request()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async(Dispatcher, Name, Request)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async', Name, <<>>, Request,
                                 undefined, undefined}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_async(Dispatcher :: dispatcher(),
                 Name :: service_name(),
                 Request :: request(),
                 Timeout :: timeout_milliseconds()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async(Dispatcher, Name, Request, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

send_async(Dispatcher, Name, Request, immediate) ->
    send_async(Dispatcher, Name, Request, ?SEND_ASYNC_INTERVAL - 1);

send_async(Dispatcher, Name, Request, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_async(Dispatcher :: dispatcher(),
                 Name :: service_name(),
                 Request :: request(),
                 Timeout :: timeout_milliseconds(),
                 PatternPid :: pattern_pid() | undefined) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async(Dispatcher, Name, Request, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

send_async(Dispatcher, Name, Request, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async', Name, <<>>, Request,
                                 undefined, undefined, PatternPid}, infinity);

send_async(Dispatcher, Name, Request, immediate, PatternPid) ->
    send_async(Dispatcher, Name, Request,
               ?SEND_ASYNC_INTERVAL - 1, PatternPid);

send_async(Dispatcher, Name, Request, Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_async(Dispatcher, Name, Request, Timeout, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name, <<>>, Request,
                                    Timeout, undefined, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_async(Dispatcher :: dispatcher(),
                 Name :: service_name(),
                 RequestInfo :: request_info(),
                 Request :: request(),
                 Timeout :: timeout_milliseconds(),
                 Priority :: priority()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async(Dispatcher, Name, RequestInfo, Request,
           undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async', Name,
                                 RequestInfo, Request,
                                 undefined, undefined}, infinity);

send_async(Dispatcher, Name, RequestInfo, Request,
           undefined, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'send_async', Name,
                                 RequestInfo, Request,
                                 undefined, Priority}, infinity);

send_async(Dispatcher, Name, RequestInfo, Request,
           immediate, Priority) ->
    send_async(Dispatcher, Name, RequestInfo, Request,
               ?SEND_ASYNC_INTERVAL - 1, Priority);

send_async(Dispatcher, Name, RequestInfo, Request,
           Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_async(Dispatcher, Name, RequestInfo, Request,
           Timeout, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_async(Dispatcher :: dispatcher(),
                 Name :: service_name(),
                 RequestInfo :: request_info(),
                 Request :: request(),
                 Timeout :: timeout_milliseconds(),
                 Priority :: priority(),
                 PatternPid :: pattern_pid() | undefined) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async(Dispatcher, Name, RequestInfo, Request,
           undefined, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async', Name,
                                 RequestInfo, Request,
                                 undefined, undefined}, infinity);

send_async(Dispatcher, Name, RequestInfo, Request,
           undefined, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 undefined, PatternPid}, infinity);

send_async(Dispatcher, Name, RequestInfo, Request,
           undefined, Priority, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'send_async', Name,
                                 RequestInfo, Request,
                                 undefined, Priority}, infinity);

send_async(Dispatcher, Name, RequestInfo, Request,
           immediate, Priority, PatternPid) ->
    send_async(Dispatcher, Name, RequestInfo, Request,
               ?SEND_ASYNC_INTERVAL - 1, Priority, PatternPid);

send_async(Dispatcher, Name, RequestInfo, Request,
           undefined, Priority, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 Priority, PatternPid}, infinity);

send_async(Dispatcher, Name, RequestInfo, Request,
           Timeout, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_async(Dispatcher, Name, RequestInfo, Request,
           Timeout, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA));

send_async(Dispatcher, Name, RequestInfo, Request,
           Timeout, Priority, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA));

send_async(Dispatcher, Name, RequestInfo, Request,
           Timeout, Priority, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% The response is sent to the service as an Erlang message which is either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec send_async_active(Dispatcher :: dispatcher(),
                        Name :: service_name(),
                        Request :: request()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_active(Dispatcher, Name, Request)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async_active', Name, <<>>, Request,
                                 undefined, undefined}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% The response is sent to the service as an Erlang message which is either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec send_async_active(Dispatcher :: dispatcher(),
                        Name :: service_name(),
                        Request :: request(),
                        Timeout :: timeout_milliseconds()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_active(Dispatcher, Name, Request, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async_active', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

send_async_active(Dispatcher, Name, Request, immediate) ->
    send_async_active(Dispatcher, Name, Request, ?SEND_ASYNC_INTERVAL - 1);

send_async_active(Dispatcher, Name, Request, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% The response is sent to the service as an Erlang message which is either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec send_async_active(Dispatcher :: dispatcher(),
                        Name :: service_name(),
                        Request :: request(),
                        Timeout :: timeout_milliseconds(),
                        PatternPid :: pattern_pid() | undefined) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_active(Dispatcher, Name, Request, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async_active', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

send_async_active(Dispatcher, Name, Request, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async_active', Name, <<>>, Request,
                                 undefined, undefined, PatternPid}, infinity);

send_async_active(Dispatcher, Name, Request, immediate, PatternPid) ->
    send_async_active(Dispatcher, Name, Request,
                      ?SEND_ASYNC_INTERVAL - 1, PatternPid);

send_async_active(Dispatcher, Name, Request, Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_async_active(Dispatcher, Name, Request, Timeout, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name, <<>>, Request,
                                    Timeout, undefined, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% The response is sent to the service as an Erlang message which is either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec send_async_active(Dispatcher :: dispatcher(),
                        Name :: service_name(),
                        RequestInfo :: request_info(),
                        Request :: request(),
                        Timeout :: timeout_milliseconds(),
                        Priority :: priority()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 undefined}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 Priority}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  immediate, Priority) ->
    send_async_active(Dispatcher, Name, RequestInfo, Request,
                      ?SEND_ASYNC_INTERVAL - 1, Priority);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% The response is sent to the service as an Erlang message which is either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec send_async_active(Dispatcher :: dispatcher(),
                        Name :: service_name(),
                        RequestInfo :: request_info(),
                        Request :: request(),
                        Timeout :: timeout_milliseconds(),
                        Priority :: priority(),
                        PatternPid :: pattern_pid() | undefined) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined, undefined}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 undefined, PatternPid}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, Priority, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined, Priority}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, Priority, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 Priority, PatternPid}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  immediate, Priority, PatternPid) ->
    send_async_active(Dispatcher, Name, RequestInfo, Request,
                      ?SEND_ASYNC_INTERVAL - 1, Priority, PatternPid);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA));

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, Priority, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA));

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, Priority, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request with a previously generated transaction id.===
%% Only meant for special transaction handling.
%% The response is sent to the service as an Erlang message which is either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec send_async_active(Dispatcher :: dispatcher(),
                        Name :: service_name(),
                        RequestInfo :: request_info(),
                        Request :: request(),
                        Timeout :: timeout_milliseconds(),
                        Priority :: priority(),
                        TransId :: trans_id(),
                        PatternPid :: pattern_pid()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, undefined, TransId, PatternPid)
    when is_pid(Dispatcher), is_list(Name),
         is_binary(TransId), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined, undefined,
                                 TransId, PatternPid}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  undefined, Priority, TransId, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_binary(TransId), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_async_active', Name,
                                 RequestInfo, Request,
                                 undefined, Priority,
                                 TransId, PatternPid}, infinity);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  immediate, Priority, TransId, PatternPid) ->
    send_async_active(Dispatcher, Name, RequestInfo, Request,
                      ?SEND_ASYNC_INTERVAL - 1, Priority, TransId, PatternPid);

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, undefined, TransId, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX,
         is_binary(TransId), is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined, TransId, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA));

send_async_active(Dispatcher, Name, RequestInfo, Request,
                  Timeout, Priority, TransId, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_binary(TransId), is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority, TransId, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% An alias for send_async.  The asynchronous service request is returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec send_async_passive(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         Request :: request()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_passive(Dispatcher, Name, Request) ->
    send_async(Dispatcher, Name, Request).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% An alias for send_async.  The asynchronous service request is returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec send_async_passive(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         Request :: request(),
                         Timeout :: timeout_milliseconds()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_passive(Dispatcher, Name, Request, Timeout) ->
    send_async(Dispatcher, Name, Request, Timeout).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% An alias for send_async.  The asynchronous service request is returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec send_async_passive(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         Request :: request(),
                         Timeout :: timeout_milliseconds(),
                         PatternPid :: pattern_pid() | undefined) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_passive(Dispatcher, Name, Request, Timeout, PatternPid) ->
    send_async(Dispatcher, Name, Request, Timeout, PatternPid).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% An alias for send_async.  The asynchronous service request is returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec send_async_passive(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         RequestInfo :: request_info(),
                         Request :: request(),
                         Timeout :: timeout_milliseconds(),
                         Priority :: priority()) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_passive(Dispatcher, Name, RequestInfo, Request,
                   Timeout, Priority) ->
    send_async(Dispatcher, Name, RequestInfo, Request,
               Timeout, Priority).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send an asynchronous service request.===
%% An alias for send_async.  The asynchronous service request is returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec send_async_passive(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         RequestInfo :: request_info(),
                         Request :: request(),
                         Timeout :: timeout_milliseconds(),
                         Priority :: priority(),
                         PatternPid :: pattern_pid() | undefined) ->
    {ok, TransId :: trans_id()} |
    {error, Reason :: error_reason()}.

send_async_passive(Dispatcher, Name, RequestInfo, Request,
                   Timeout, Priority, PatternPid) ->
    send_async(Dispatcher, Name, RequestInfo, Request,
               Timeout, Priority, PatternPid).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a synchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_sync(Dispatcher :: dispatcher(),
                Name :: service_name(),
                Request :: request()) ->
    {ok, ResponseInfo :: response_info(), Response :: response()} |
    {ok, Response :: response()} |
    {error, Reason :: error_reason_sync()}.

send_sync(Dispatcher, Name, Request)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_sync', Name, <<>>, Request,
                                 undefined, undefined}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a synchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_sync(Dispatcher :: dispatcher(),
                Name :: service_name(),
                Request :: request(),
                Timeout :: timeout_milliseconds()) ->
    {ok, ResponseInfo :: response_info(), Response :: response()} |
    {ok, Response :: response()} |
    {error, Reason :: error_reason_sync()}.

send_sync(Dispatcher, Name, Request, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_sync', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

send_sync(Dispatcher, Name, Request, immediate) ->
    send_sync(Dispatcher, Name, Request, ?SEND_SYNC_INTERVAL - 1);

send_sync(Dispatcher, Name, Request, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a synchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_sync(Dispatcher :: dispatcher(),
                Name :: service_name(),
                Request :: request(),
                Timeout :: timeout_milliseconds(),
                PatternPid :: pattern_pid() | undefined) ->
    {ok, ResponseInfo :: response_info(), Response :: response()} |
    {ok, Response :: response()} |
    {error, Reason :: error_reason_sync()}.

send_sync(Dispatcher, Name, Request, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_sync', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

send_sync(Dispatcher, Name, Request, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_sync', Name, <<>>, Request,
                                 undefined, undefined, PatternPid}, infinity);

send_sync(Dispatcher, Name, Request, immediate, PatternPid) ->
    send_sync(Dispatcher, Name, Request,
              ?SEND_SYNC_INTERVAL - 1, PatternPid);

send_sync(Dispatcher, Name, Request, Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_sync(Dispatcher, Name, Request, Timeout, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name, <<>>, Request,
                                    Timeout, undefined, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a synchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_sync(Dispatcher :: dispatcher(),
                Name :: service_name(),
                RequestInfo :: request_info(),
                Request :: request(),
                Timeout :: timeout_milliseconds(),
                Priority :: priority()) ->
    {ok, ResponseInfo :: response_info(), Response :: response()} |
    {ok, Response :: response()} |
    {error, Reason :: error_reason_sync()}.

send_sync(Dispatcher, Name, RequestInfo, Request,
          undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_sync', Name,
                                 RequestInfo, Request,
                                 undefined, undefined}, infinity);

send_sync(Dispatcher, Name, RequestInfo, Request,
          undefined, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'send_sync', Name,
                                 RequestInfo, Request,
                                 undefined, Priority}, infinity);

send_sync(Dispatcher, Name, RequestInfo, Request,
          immediate, Priority) ->
    send_sync(Dispatcher, Name, RequestInfo, Request,
              ?SEND_SYNC_INTERVAL - 1, Priority);

send_sync(Dispatcher, Name, RequestInfo, Request,
          Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_sync(Dispatcher, Name, RequestInfo, Request,
          Timeout, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a synchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec send_sync(Dispatcher :: dispatcher(),
                Name :: service_name(),
                RequestInfo :: request_info(),
                Request :: request(),
                Timeout :: timeout_milliseconds(),
                Priority :: priority(),
                PatternPid :: pattern_pid() | undefined) ->
    {ok, ResponseInfo :: response_info(), Response :: response()} |
    {ok, Response :: response()} |
    {error, Reason :: error_reason_sync()}.

send_sync(Dispatcher, Name, RequestInfo, Request,
          undefined, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'send_sync', Name,
                                 RequestInfo, Request,
                                 undefined, undefined}, infinity);

send_sync(Dispatcher, Name, RequestInfo, Request,
          undefined, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_sync', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 undefined, PatternPid}, infinity);

send_sync(Dispatcher, Name, RequestInfo, Request,
          undefined, Priority, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'send_sync', Name,
                                 RequestInfo, Request,
                                 undefined, Priority}, infinity);

send_sync(Dispatcher, Name, RequestInfo, Request,
          undefined, Priority, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_tuple(PatternPid) ->
    gen_server:call(Dispatcher, {'send_sync', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 Priority, PatternPid}, infinity);

send_sync(Dispatcher, Name, RequestInfo, Request,
          immediate, Priority, PatternPid) ->
    send_sync(Dispatcher, Name, RequestInfo, Request,
              ?SEND_SYNC_INTERVAL - 1, Priority, PatternPid);

send_sync(Dispatcher, Name, RequestInfo, Request,
          Timeout, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

send_sync(Dispatcher, Name, RequestInfo, Request,
          Timeout, undefined, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA));

send_sync(Dispatcher, Name, RequestInfo, Request,
          Timeout, Priority, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA));

send_sync(Dispatcher, Name, RequestInfo, Request,
          Timeout, Priority, PatternPid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW,
         is_tuple(PatternPid) ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'send_sync', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority, PatternPid},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% Asynchronous service requests are sent to all services that have
%% subscribed to the service name pattern that matches the destination.
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async(Dispatcher :: dispatcher(),
                  Name :: service_name(),
                  Request :: request()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async(Dispatcher, Name, Request)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'mcast_async', Name, <<>>, Request,
                                 undefined, undefined}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% Asynchronous service requests are sent to all services that have
%% subscribed to the service name pattern that matches the destination.
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async(Dispatcher :: dispatcher(),
                  Name :: service_name(),
                  Request :: request(),
                  Timeout :: timeout_milliseconds()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async(Dispatcher, Name, Request, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'mcast_async', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

mcast_async(Dispatcher, Name, Request, immediate) ->
    mcast_async(Dispatcher, Name, Request, ?MCAST_ASYNC_INTERVAL - 1);

mcast_async(Dispatcher, Name, Request, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'mcast_async', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% Asynchronous service requests are sent to all services that have
%% subscribed to the service name pattern that matches the destination.
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async(Dispatcher :: dispatcher(),
                  Name :: service_name(),
                  RequestInfo :: request_info(),
                  Request :: request(),
                  Timeout :: timeout_milliseconds(),
                  Priority :: priority()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async(Dispatcher, Name, RequestInfo, Request, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'mcast_async', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 undefined}, infinity);

mcast_async(Dispatcher, Name, RequestInfo, Request, undefined, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'mcast_async', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 Priority}, infinity);

mcast_async(Dispatcher, Name, RequestInfo, Request, immediate, Priority) ->
    mcast_async(Dispatcher, Name, RequestInfo, Request,
                ?MCAST_ASYNC_INTERVAL - 1, Priority);

mcast_async(Dispatcher, Name, RequestInfo, Request, Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'mcast_async', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

mcast_async(Dispatcher, Name, RequestInfo, Request, Timeout, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'mcast_async', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% Asynchronous service requests are sent to all services that have
%% subscribed to the service name pattern that matches the destination.
%% The responses are sent to the service as Erlang messages that are either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async_active(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         Request :: request()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async_active(Dispatcher, Name, Request)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'mcast_async_active', Name, <<>>, Request,
                                 undefined, undefined}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% Asynchronous service requests are sent to all services that have
%% subscribed to the service name pattern that matches the destination.
%% The responses are sent to the service as Erlang messages that are either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async_active(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         Request :: request(),
                         Timeout :: timeout_milliseconds()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async_active(Dispatcher, Name, Request, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'mcast_async_active', Name, <<>>, Request,
                                 undefined, undefined}, infinity);

mcast_async_active(Dispatcher, Name, Request, immediate) ->
    mcast_async_active(Dispatcher, Name, Request, ?MCAST_ASYNC_INTERVAL - 1);

mcast_async_active(Dispatcher, Name, Request, Timeout)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'mcast_async_active', Name, <<>>, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% Asynchronous service requests are sent to all services that have
%% subscribed to the service name pattern that matches the destination.
%% The responses are sent to the service as Erlang messages that are either:
%% `{return_async_active, Name, Pattern, ResponseInfo, Response, Timeout, TransId}'
%% (or)
%% `{timeout_async_active, TransId}'
%% use `-include_lib("cloudi_core/include/cloudi_service.hrl").' to have:
%% `#return_async_active{}' (or) `#timeout_async_active{}'
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async_active(Dispatcher :: dispatcher(),
                         Name :: service_name(),
                         RequestInfo :: request_info(),
                         Request :: request(),
                         Timeout :: timeout_milliseconds(),
                         Priority :: priority()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async_active(Dispatcher, Name, RequestInfo, Request, undefined, undefined)
    when is_pid(Dispatcher), is_list(Name) ->
    gen_server:call(Dispatcher, {'mcast_async_active', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 undefined}, infinity);

mcast_async_active(Dispatcher, Name, RequestInfo, Request, undefined, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    gen_server:call(Dispatcher, {'mcast_async_active', Name,
                                 RequestInfo, Request,
                                 undefined,
                                 Priority}, infinity);

mcast_async_active(Dispatcher, Name, RequestInfo, Request,
                   immediate, Priority) ->
    mcast_async_active(Dispatcher, Name, RequestInfo, Request,
                       ?MCAST_ASYNC_INTERVAL - 1, Priority);

mcast_async_active(Dispatcher, Name, RequestInfo, Request, Timeout, undefined)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'mcast_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, undefined},
                                   Timeout + ?TIMEOUT_DELTA));

mcast_async_active(Dispatcher, Name, RequestInfo, Request, Timeout, Priority)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'mcast_async_active', Name,
                                    RequestInfo, Request,
                                    Timeout, Priority},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% An alias for mcast_async.  The asynchronous service requests are returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async_passive(Dispatcher :: dispatcher(),
                          Name :: service_name(),
                          Request :: request()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async_passive(Dispatcher, Name, Request) ->
    mcast_async(Dispatcher, Name, Request).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% An alias for mcast_async.  The asynchronous service requests are returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async_passive(Dispatcher :: dispatcher(),
                          Name :: service_name(),
                          Request :: request(),
                          Timeout :: timeout_milliseconds()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async_passive(Dispatcher, Name, Request, Timeout) ->
    mcast_async(Dispatcher, Name, Request, Timeout).

%%-------------------------------------------------------------------------
%% @doc
%% ===Send a multicast asynchronous service request.===
%% An alias for mcast_async.  The asynchronous service requests are returned
%% and handled the same way as within external services.
%% @end
%%-------------------------------------------------------------------------

-spec mcast_async_passive(Dispatcher :: dispatcher(),
                          Name :: service_name(),
                          RequestInfo :: request_info(),
                          Request :: request(),
                          Timeout :: timeout_milliseconds(),
                          Priority :: priority()) ->
    {ok, TransIdList :: list(trans_id())} |
    {error, Reason :: error_reason()}.

mcast_async_passive(Dispatcher, Name, RequestInfo, Request,
                    Timeout, Priority) ->
    mcast_async(Dispatcher, Name, RequestInfo, Request, Timeout, Priority).

%%-------------------------------------------------------------------------
%% @doc
%% ===Forward a service request.===
%% @end
%%-------------------------------------------------------------------------

-spec forward(Dispatcher :: dispatcher(),
              Type :: request_type(),
              Name :: service_name(),
              RequestInfo :: request_info(),
              Request :: request(),
              Timeout :: timeout_value_milliseconds(),
              Priority :: priority(),
              TransId :: trans_id(),
              Pid :: pid()) ->
    no_return().

forward(Dispatcher, 'send_async', Name, RequestInfo, Request,
        Timeout, Priority, TransId, Pid) ->
    forward_async(Dispatcher, Name, RequestInfo, Request,
                  Timeout, Priority, TransId, Pid);

forward(Dispatcher, 'send_sync', Name, RequestInfo, Request,
        Timeout, Priority, TransId, Pid) ->
    forward_sync(Dispatcher, Name, RequestInfo, Request,
                 Timeout, Priority, TransId, Pid).

%%-------------------------------------------------------------------------
%% @doc
%% ===Forward an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec forward_async(Dispatcher :: dispatcher(),
                    Name :: service_name(),
                    RequestInfo :: request_info(),
                    Request :: request(),
                    Timeout :: timeout_value_milliseconds(),
                    Priority :: priority(),
                    TransId :: trans_id(),
                    Pid :: pid()) ->
    no_return().

forward_async(Dispatcher, Name, RequestInfo, Request,
              Timeout, Priority, TransId, Pid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         is_binary(TransId), is_pid(Pid),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    erlang:throw({cloudi_service_forward,
                  {'cloudi_service_forward_async_retry', Name,
                   RequestInfo, Request,
                   Timeout, Priority, TransId, Pid}}).

%%-------------------------------------------------------------------------
%% @doc
%% ===Forward a synchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec forward_sync(Dispatcher :: dispatcher(),
                   Name :: service_name(),
                   RequestInfo :: request_info(),
                   Request :: request(),
                   Timeout :: timeout_value_milliseconds(),
                   Priority :: priority(),
                   TransId :: trans_id(),
                   Pid :: pid()) ->
    no_return().

forward_sync(Dispatcher, Name, RequestInfo, Request,
             Timeout, Priority, TransId, Pid)
    when is_pid(Dispatcher), is_list(Name), is_integer(Timeout),
         is_binary(TransId), is_pid(Pid),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX, is_integer(Priority),
         Priority >= ?PRIORITY_HIGH, Priority =< ?PRIORITY_LOW ->
    erlang:throw({cloudi_service_forward,
                  {'cloudi_service_forward_sync_retry', Name,
                   RequestInfo, Request,
                   Timeout, Priority, TransId, Pid}}).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return a service response.===
%% @end
%%-------------------------------------------------------------------------

-spec return(Dispatcher :: dispatcher(),
             Response :: response()) ->
    no_return().

return(Dispatcher, Response)
    when is_pid(Dispatcher) ->
    erlang:throw({cloudi_service_return, {Response}}).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return a service response.===
%% @end
%%-------------------------------------------------------------------------

-spec return(Dispatcher :: dispatcher(),
             ResponseInfo :: response_info(),
             Response :: response()) ->
    no_return().

return(Dispatcher, ResponseInfo, Response)
    when is_pid(Dispatcher) ->
    erlang:throw({cloudi_service_return, {ResponseInfo, Response}}).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return a service response.===
%% @end
%%-------------------------------------------------------------------------

-spec return(Dispatcher :: dispatcher(),
             Type :: request_type(),
             Name :: service_name(),
             Pattern :: service_name_pattern(),
             ResponseInfo :: response_info(),
             Response :: response(),
             Timeout :: timeout_value_milliseconds(),
             TransId :: trans_id(),
             Pid :: pid()) ->
    no_return().

return(Dispatcher, 'send_async', Name, Pattern, ResponseInfo, Response,
       Timeout, TransId, Pid) ->
    return_async(Dispatcher, Name, Pattern, ResponseInfo, Response,
                 Timeout, TransId, Pid);

return(Dispatcher, 'send_sync', Name, Pattern, ResponseInfo, Response,
       Timeout, TransId, Pid) ->
    return_sync(Dispatcher, Name, Pattern, ResponseInfo, Response,
                Timeout, TransId, Pid).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return an asynchronous service response.===
%% @end
%%-------------------------------------------------------------------------

-spec return_async(Dispatcher :: dispatcher(),
                   Name :: service_name(),
                   Pattern :: service_name_pattern(),
                   ResponseInfo :: response_info(),
                   Response :: response(),
                   Timeout :: timeout_value_milliseconds(),
                   TransId :: trans_id(),
                   Pid :: pid()) ->
    no_return().

return_async(Dispatcher, Name, Pattern, ResponseInfo, Response,
             Timeout, TransId, Pid)
    when is_pid(Dispatcher), is_list(Name), is_list(Pattern),
         is_integer(Timeout), is_binary(TransId), is_pid(Pid),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    erlang:throw({cloudi_service_return,
                  {'cloudi_service_return_async', Name, Pattern,
                   ResponseInfo, Response,
                   Timeout, TransId, Pid}}).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return a synchronous service response.===
%% @end
%%-------------------------------------------------------------------------

-spec return_sync(Dispatcher :: dispatcher(),
                  Name :: service_name(),
                  Pattern :: service_name_pattern(),
                  ResponseInfo :: response_info(),
                  Response :: response(),
                  Timeout :: timeout_value_milliseconds(),
                  TransId :: trans_id(),
                  Pid :: pid()) ->
    no_return().

return_sync(Dispatcher, Name, Pattern, ResponseInfo, Response,
            Timeout, TransId, Pid)
    when is_pid(Dispatcher), is_list(Name), is_list(Pattern),
         is_integer(Timeout), is_binary(TransId), is_pid(Pid),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    erlang:throw({cloudi_service_return,
                  {'cloudi_service_return_sync', Name, Pattern,
                   ResponseInfo, Response,
                   Timeout, TransId, Pid}}).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return a service response without exiting the request handler.===
%% Should rarely, if ever, be used.  If the service has the option
%% request_timeout_adjustment == true, the adjustment will not occur when
%% this function is used.  Also, the service's
%% response_timeout_immediate_max option will not prevent a null response
%% from being sent when this function is used.
%% @end
%%-------------------------------------------------------------------------

-spec return_nothrow(Dispatcher :: dispatcher(),
                     Type :: request_type(),
                     Name :: service_name(),
                     Pattern :: service_name_pattern(),
                     ResponseInfo :: response_info(),
                     Response :: response(),
                     Timeout :: timeout_value_milliseconds(),
                     TransId :: trans_id(),
                     Pid :: pid()) ->
    ok.

return_nothrow(Dispatcher, 'send_async', Name, Pattern, ResponseInfo, Response,
               Timeout, TransId, Pid)
    when is_pid(Dispatcher), is_list(Name), is_list(Pattern),
         is_integer(Timeout), is_binary(TransId), is_pid(Pid),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    Pid ! {'cloudi_service_return_async', Name, Pattern,
           ResponseInfo, Response,
           Timeout, TransId, Pid},
    ok;

return_nothrow(Dispatcher, 'send_sync', Name, Pattern, ResponseInfo, Response,
               Timeout, TransId, Pid)
    when is_pid(Dispatcher), is_list(Name), is_list(Pattern),
         is_integer(Timeout), is_binary(TransId), is_pid(Pid),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    Pid ! {'cloudi_service_return_sync', Name, Pattern,
           ResponseInfo, Response,
           Timeout, TransId, Pid},
    ok.

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive an asynchronous service request.===
%% Use a null TransId to receive the oldest service request.
%% @end
%%-------------------------------------------------------------------------

-spec recv_async(Dispatcher :: dispatcher()) ->
    {ok, ResponseInfo :: response_info(), Response :: response(),
     TransId :: trans_id()} |
    {error, Reason :: error_reason_sync()}.

recv_async(Dispatcher)
    when is_pid(Dispatcher) ->
    gen_server:call(Dispatcher,
                    {'recv_async', <<0:128>>, true}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive an asynchronous service request.===
%% Either use the supplied TransId to receive the specific service request
%% or use a null TransId to receive the oldest service request.
%% @end
%%-------------------------------------------------------------------------

-spec recv_async(Dispatcher :: dispatcher(),
                 timeout_milliseconds() | trans_id()) ->
    {ok, ResponseInfo :: response_info(), Response :: response(),
     TransId :: trans_id()} |
    {error, Reason :: error_reason_sync()}.

recv_async(Dispatcher, TransId)
    when is_pid(Dispatcher), is_binary(TransId) ->
    gen_server:call(Dispatcher,
                    {'recv_async', TransId, true}, infinity);

recv_async(Dispatcher, undefined)
    when is_pid(Dispatcher) ->
    gen_server:call(Dispatcher,
                    {'recv_async', <<0:128>>, true}, infinity);

recv_async(Dispatcher, immediate) ->
    recv_async(Dispatcher, ?RECV_ASYNC_INTERVAL - 1);

recv_async(Dispatcher, Timeout)
    when is_pid(Dispatcher), is_integer(Timeout),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'recv_async', Timeout, <<0:128>>, true},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive an asynchronous service request.===
%% Either use the supplied TransId to receive the specific service request
%% or use a null TransId to receive the oldest service request.
%% @end
%%-------------------------------------------------------------------------

-spec recv_async(Dispatcher :: dispatcher(),
                 timeout_milliseconds() | trans_id(),
                 trans_id() | boolean()) ->
    {ok, ResponseInfo :: response_info(), Response :: response(),
     TransId :: trans_id()} |
    {error, Reason :: error_reason_sync()}.

recv_async(Dispatcher, undefined, TransId)
    when is_pid(Dispatcher), is_binary(TransId) ->
    gen_server:call(Dispatcher,
                    {'recv_async', TransId, true}, infinity);

recv_async(Dispatcher, immediate, TransId) ->
    recv_async(Dispatcher, ?RECV_ASYNC_INTERVAL - 1, TransId);

recv_async(Dispatcher, Timeout, TransId)
    when is_pid(Dispatcher), is_integer(Timeout), is_binary(TransId),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'recv_async', Timeout, TransId, true},
                                   Timeout + ?TIMEOUT_DELTA));

recv_async(Dispatcher, Timeout, Consume)
    when is_pid(Dispatcher), is_integer(Timeout), is_boolean(Consume),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'recv_async', Timeout, <<0:128>>, Consume},
                                   Timeout + ?TIMEOUT_DELTA));

recv_async(Dispatcher, TransId, Consume)
    when is_pid(Dispatcher), is_binary(TransId), is_boolean(Consume) ->
    gen_server:call(Dispatcher,
                    {'recv_async', TransId, Consume}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive an asynchronous service request.===
%% @end
%%-------------------------------------------------------------------------

-spec recv_async(Dispatcher :: dispatcher(),
                 Timeout :: timeout_milliseconds(),
                 TransId :: trans_id(),
                 Consume :: boolean()) ->
    {ok, ResponseInfo :: response_info(), Response :: response(),
     TransId :: trans_id()} |
    {error, Reason :: error_reason_sync()}.

recv_async(Dispatcher, undefined, TransId, Consume)
    when is_pid(Dispatcher), is_binary(TransId), is_boolean(Consume) ->
    gen_server:call(Dispatcher,
                    {'recv_async', TransId, Consume}, infinity);

recv_async(Dispatcher, immediate, TransId, Consume) ->
    recv_async(Dispatcher, ?RECV_ASYNC_INTERVAL - 1, TransId, Consume);

recv_async(Dispatcher, Timeout, TransId, Consume)
    when is_pid(Dispatcher), is_integer(Timeout), is_binary(TransId),
         is_boolean(Consume), Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'recv_async', Timeout, TransId, Consume},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive asynchronous service requests.===
%% @end
%%-------------------------------------------------------------------------

-spec recv_asyncs(Dispatcher :: dispatcher(),
                  TransIdList :: list(trans_id())) ->
    {ok, list({ResponseInfo :: response_info(),
               Response :: response(), TransId :: trans_id()})} |
    {error, Reason :: error_reason_sync()}.

recv_asyncs(Dispatcher, [_ | _] = TransIdList)
    when is_pid(Dispatcher), is_list(TransIdList) ->
    gen_server:call(Dispatcher,
                    {'recv_asyncs',
                     [{<<>>, <<>>, TransId} ||
                      TransId <- TransIdList], true}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive asynchronous service requests.===
%% @end
%%-------------------------------------------------------------------------

-spec recv_asyncs(Dispatcher :: dispatcher(),
                  Timeout :: timeout_milliseconds(),
                  TransIdList :: list(trans_id())) ->
    {ok, list({ResponseInfo :: response_info(), Response :: response(),
               TransId :: trans_id()})} |
    {error, Reason :: error_reason_sync()}.

recv_asyncs(Dispatcher, undefined, [_ | _] = TransIdList)
    when is_pid(Dispatcher), is_list(TransIdList) ->
    gen_server:call(Dispatcher,
                    {'recv_asyncs',
                     [{<<>>, <<>>, TransId} ||
                      TransId <- TransIdList], true}, infinity);

recv_asyncs(Dispatcher, immediate, TransIdList) ->
    recv_asyncs(Dispatcher, ?RECV_ASYNC_INTERVAL - 1, TransIdList);

recv_asyncs(Dispatcher, Timeout, [_ | _] = TransIdList)
    when is_pid(Dispatcher), is_integer(Timeout), is_list(TransIdList),
         Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'recv_asyncs', Timeout,
                                    [{<<>>, <<>>, TransId} ||
                                     TransId <- TransIdList], true},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Receive asynchronous service requests.===
%% @end
%%-------------------------------------------------------------------------

-spec recv_asyncs(Dispatcher :: dispatcher(),
                  Timeout :: timeout_milliseconds(),
                  TransIdList :: list(trans_id()),
                  Consume :: boolean()) ->
    {ok, list({ResponseInfo :: response_info(), Response :: response(),
               TransId :: trans_id()})} |
    {error, Reason :: error_reason_sync()}.

recv_asyncs(Dispatcher, immediate, TransIdList, Consume) ->
    recv_asyncs(Dispatcher, ?RECV_ASYNC_INTERVAL - 1, TransIdList, Consume);

recv_asyncs(Dispatcher, Timeout, [_ | _] = TransIdList, Consume)
    when is_pid(Dispatcher), is_integer(Timeout), is_list(TransIdList),
         is_boolean(Consume), Timeout >= 0, Timeout =< ?TIMEOUT_MAX ->
    ?CATCH_TIMEOUT(gen_server:call(Dispatcher,
                                   {'recv_asyncs', Timeout,
                                    [{<<>>, <<>>, TransId} ||
                                     TransId <- TransIdList], Consume},
                                   Timeout + ?TIMEOUT_DELTA)).

%%-------------------------------------------------------------------------
%% @doc
%% ===Configured service default prefix.===
%% All subscribed/unsubscribed service names use this prefix.  The prefix
%% defines the scope of the service.
%% @end
%%-------------------------------------------------------------------------

-spec prefix(Dispatcher :: dispatcher()) ->
    Prefix :: service_name_pattern().

prefix(Dispatcher) ->
    gen_server:call(Dispatcher, prefix, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Configured service default asynchronous timeout (in milliseconds).===
%% @end
%%-------------------------------------------------------------------------

-spec timeout_async(Dispatcher :: dispatcher()) ->
    TimeoutAsync :: cloudi_service_api:timeout_milliseconds().

timeout_async(Dispatcher) ->
    gen_server:call(Dispatcher, timeout_async, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Configured service default synchronous timeout (in milliseconds).===
%% @end
%%-------------------------------------------------------------------------

-spec timeout_sync(Dispatcher :: dispatcher()) ->
    TimeoutSync :: cloudi_service_api:timeout_milliseconds().

timeout_sync(Dispatcher) ->
    gen_server:call(Dispatcher, timeout_sync, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Maximum possible service request timeout (in milliseconds).===
%% @end
%%-------------------------------------------------------------------------

-spec timeout_max(Dispatcher :: dispatcher()) ->
    TimeoutMax :: cloudi_service_api:timeout_milliseconds().

timeout_max(Dispatcher)
    when is_pid(Dispatcher) ->
    ?TIMEOUT_MAX.

%%-------------------------------------------------------------------------
%% @doc
%% ===Configured service default priority.===
%% @end
%%-------------------------------------------------------------------------

-spec priority_default(Dispatcher :: dispatcher()) ->
    PriorityDefault :: cloudi_service_api:priority().

priority_default(Dispatcher) ->
    gen_server:call(Dispatcher, priority_default, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Configured service destination refresh is immediate.===
%% @end
%%-------------------------------------------------------------------------

-spec destination_refresh_immediate(Dispatcher :: dispatcher()) ->
    boolean().

destination_refresh_immediate(Dispatcher) ->
    gen_server:call(Dispatcher, destination_refresh_immediate, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Configured service destination refresh is lazy.===
%% @end
%%-------------------------------------------------------------------------

-spec destination_refresh_lazy(Dispatcher :: dispatcher()) ->
    boolean().

destination_refresh_lazy(Dispatcher) ->
    gen_server:call(Dispatcher, destination_refresh_lazy, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Get a list of all service name patterns a service request source is subscribed to.===
%% The source pid can be found at:
%%
%% `cloudi_service_handle_request(_, _, _, _, _, _, _, _, Pid, _, _)'
%% @end
%%-------------------------------------------------------------------------

-spec source_subscriptions(Dispatcher :: dispatcher(),
                           Pid :: source()) ->
    list(service_name_pattern()).

source_subscriptions(Dispatcher, Pid)
    when is_pid(Pid) ->
    gen_server:call(Dispatcher, {source_subscriptions, Pid}, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Get the context options from the service's configuration.===
%% A service would only use this when delaying the creation of a context
%% for child processes.
%% @end
%%-------------------------------------------------------------------------

-spec context_options(Dispatcher :: dispatcher()) ->
    cloudi:options().

context_options(Dispatcher) ->
    gen_server:call(Dispatcher, context_options, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% ===Return a new transaction id.===
%% The same data as used when sending service requests is used.
%% @end
%%-------------------------------------------------------------------------

-spec trans_id(Dispatcher :: dispatcher()) ->
    trans_id().

trans_id(Dispatcher) ->
    gen_server:call(Dispatcher, trans_id, infinity).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_environment:lookup/0} instead
%% @end
%%-------------------------------------------------------------------------

-spec environment_lookup() ->
    trie:trie().

environment_lookup() ->
    cloudi_environment:lookup().

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_environment:transform/1} instead
%% @end
%%-------------------------------------------------------------------------

-spec environment_transform(String :: string()) ->
    string().

environment_transform(String) ->
    cloudi_environment:transform(String).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_environment:transform/2} instead
%% @end
%%-------------------------------------------------------------------------

-spec environment_transform(String :: string(),
                            Lookup :: trie:trie()) ->
    string().

environment_transform(String, Lookup) ->
    cloudi_environment:transform(String, Lookup).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_service_name:new/2} instead
%% @end
%%-------------------------------------------------------------------------

-spec service_name_new(Pattern :: string(),
                       Parameters :: list(string())) ->
    {ok, string()} |
    {error, parameters_ignored | parameter_missing}.

service_name_new(Pattern, Parameters) ->
    cloudi_service_name:new(Pattern, Parameters).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_service_name:new/4} instead
%% @end
%%-------------------------------------------------------------------------

-spec service_name_new(Pattern :: string(),
                       Parameters :: list(string()),
                       ParametersSelected :: list(pos_integer()),
                       ParametersStrictMatching :: boolean()) ->
    {ok, string()} |
    {error,
     parameters_ignored | parameter_missing | parameters_selected_empty |
     {parameters_selected_ignored, list(pos_integer())} | 
     {parameters_selected_missing, pos_integer()}}.

service_name_new(Pattern, Parameters, ParametersSelected,
                 ParametersStrictMatching) ->
    cloudi_service_name:new(Pattern, Parameters, ParametersSelected,
                            ParametersStrictMatching).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_service_name:parse/2} instead
%% @end
%%-------------------------------------------------------------------------

-spec service_name_parse(Name :: string(),
                         Pattern :: string()) ->
    list(string()) | error.

service_name_parse(Name, Pattern) ->
    cloudi_service_name:parse(Name, Pattern).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_service_name:parse_with_suffix/2} instead
%% @end
%%-------------------------------------------------------------------------

-spec service_name_parse_with_suffix(Name :: string(),
                                     Pattern :: string()) ->
    {list(string()), string()} | error.

service_name_parse_with_suffix(Name, Pattern) ->
    cloudi_service_name:parse_with_suffix(Name, Pattern).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_request:http_qs_parse/1} instead
%% @end
%%-------------------------------------------------------------------------

-spec request_http_qs_parse(Request :: binary() |
                                       list({any(), any()})) ->
    Result :: dict().

request_http_qs_parse(Request) ->
    cloudi_request:http_qs_parse(Request).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_request_info:key_value_new/1} instead
%% @end
%%-------------------------------------------------------------------------

-spec request_info_key_value_new(RequestInfo ::
                                     cloudi_key_value:key_values()) ->
    Result :: binary().

request_info_key_value_new(RequestInfo) ->
    cloudi_request_info:key_value_new(RequestInfo).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_request_info:key_value_parse/1} instead
%% @end
%%-------------------------------------------------------------------------

-spec request_info_key_value_parse(RequestInfo :: binary() |
                                                  list({any(), any()})) ->
    Result :: dict().

request_info_key_value_parse(RequestInfo) ->
    cloudi_request_info:key_value_parse(RequestInfo).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_key_value:erase/2} instead
%% @end
%%-------------------------------------------------------------------------

-spec key_value_erase(Key :: any(),
                      KeyValues :: cloudi_key_value:key_values()) ->
    NewKeyValues :: cloudi_key_value:key_values().

key_value_erase(Key, KeyValues) ->
    cloudi_key_value:erase(Key, KeyValues).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_key_value:find/2} instead
%% @end
%%-------------------------------------------------------------------------

-spec key_value_find(Key :: any(),
                     KeyValues :: cloudi_key_value:key_values()) ->
    {ok, Value :: any()} |
    error.

key_value_find(Key, KeyValues) ->
    cloudi_key_value:find(Key, KeyValues).

%%-------------------------------------------------------------------------
%% @doc
%% @deprecated Use {@link cloudi_key_value:store/3} instead
%% @end
%%-------------------------------------------------------------------------

-spec key_value_store(Key :: any(),
                      Value :: any(),
                      KeyValues :: cloudi_key_value:key_values()) ->
    NewKeyValues :: cloudi_key_value:key_values().

key_value_store(Key, Value, KeyValues) ->
    cloudi_key_value:store(Key, Value, KeyValues).

%%%------------------------------------------------------------------------
%%% edoc functions
%%%------------------------------------------------------------------------

%%-------------------------------------------------------------------------
%% @doc
%% ===Initialize the internal service.===
%% Create the internal service state.  Do any initial service subscriptions
%% necessary.  Send service requests, if required for service initialization.
%% State implicitly becomes 'undefined' if not provided to 'stop'.
%% @end
%%-------------------------------------------------------------------------

-spec 'Module:cloudi_service_init'(Args :: list(),
                                   Prefix :: service_name_pattern(),
                                   Dispatcher :: dispatcher()) ->
    {ok, State :: any()} |
    {stop, Reason :: any()} |
    {stop, Reason :: any(), State :: any()}.

'Module:cloudi_service_init'(_, _, _) ->
    {ok, state}.

%%-------------------------------------------------------------------------
%% @doc
%% ===Handle an incoming service request.===
%% The request_pid_uses and request_pid_options service configuration options
%% control the Erlang process used to call this function.
%% @end
%%-------------------------------------------------------------------------

-spec 'Module:cloudi_service_handle_request'(Type :: request_type(),
                                             Name :: service_name(),
                                             Pattern :: service_name_pattern(),
                                             RequestInfo :: request_info(),
                                             Request :: request(),
                                             Timeout ::
                                                timeout_value_milliseconds(),
                                             Priority :: priority(),
                                             TransId :: trans_id(),
                                             Source :: source(),
                                             State :: any(),
                                             Dispatcher :: dispatcher()) ->
    {reply, Response :: response(), NewState :: any()} |
    {reply, ResponseInfo :: response_info(), Response :: response(),
     NewState :: any()} |
    {forward, NextName :: service_name(),
     NextRequestInfo :: request_info(), NextRequest :: request(),
     NewState :: any()} |
    {forward, NextName :: service_name(),
     NextRequestInfo :: request_info(), NextRequest :: request(),
     NextTimeout :: timeout_value_milliseconds(), NextPriority :: priority(),
     NewState :: any()} |
    {noreply, NewState :: any()} |
    {stop, Reason :: any(), NewState :: any()}.

'Module:cloudi_service_handle_request'(_, _, _, _, _, _, _, _, _, _, _) ->
    {reply, response, state}.

%%-------------------------------------------------------------------------
%% @doc
%% ===Handle an incoming Erlang message.===
%% The info_pid_uses and info_pid_options service configuration options
%% control the Erlang process used to call this function.
%% @end
%%-------------------------------------------------------------------------

-spec 'Module:cloudi_service_handle_info'(Request :: any(),
                                          State :: any(),
                                          Dispatcher :: dispatcher()) ->
    {noreply, NewState :: any()} |
    {stop, Reason :: any(), NewState :: any()}.

'Module:cloudi_service_handle_info'(_, _, _) ->
    {noreply, state}.

%%-------------------------------------------------------------------------
%% @doc
%% ===Handle service termination.===
%% cloudi_service_terminate/2 is always called, even when cloudi_service_init/3
%% returns a stop tuple.  When State is unset in the stop tuple, the
%% cloudi_service_terminate/2 function is called with State equal to
%% 'undefined'.  Always calling the cloudi_service_terminate/2 function differs
%% from how Erlang/OTP behaviours handle the init/1 function returning a stop
%% tuple, but this approach can help prevent problems managing any global
%% state that might exist that is connected to a service, or simply services
%% that are only partially initialized.
%% @end
%%-------------------------------------------------------------------------

-spec 'Module:cloudi_service_terminate'(Reason :: any(),
                                        State :: any()) ->
    ok.

'Module:cloudi_service_terminate'(_, _) ->
    ok.

%%%------------------------------------------------------------------------
%%% Private functions
%%%------------------------------------------------------------------------

