%%%-------------------------------------------------------------------
%%% File    : my_app_xref.erl
%%% Author  : Samuel Rivas
%%% Description : XREF useful tests for my_app
%%%
%%% Created : 19 May 2006 by Samuel Rivas
%%%-------------------------------------------------------------------
-module(my_app_xref).

-define(XREF_SERVER, my_app_xref_server).

-export([start/0, stop/0, restart/0, undefined/0, unresolved/0, deprecated/0,
	 unused/0, all/0, reload/0, to/2, to/3]).

start() ->
    {ok, _} = xref:start(?XREF_SERVER),
    load_otp(),

    %% Load anything that your app needs here

    load_my_app(),
    ok.

stop() ->
    xref:stop(?XREF_SERVER).

restart() ->
    stop(),
    ok = start().

reload() ->
    unload_my_app(),
    load_my_app().

undefined() ->
    %% Look for wrong function calls (extenal call to a function that does not
    %% exist)
    xref_query("UNDEFINED CALLS",
	       "(XC - UC) | ((Fun) my_app : App) || (XU - X - B)").
unresolved() ->
    %% Look for abstract function calls (they are not errors in compile time,
    %% but it may be useful when searching for failure points)
    xref_query("UNRESOLVED CALLS",
	       "UC | ((Fun) my_app : App) || (XU - X - B)").

deprecated() ->
    %% Look for deprecated functions called from my_app application (the
    %% compiler raises warning on that too)
    xref_query("DEPRECATED CALLS", "E | (Fun) my_app:App || DF").

unused() ->
    %% Look for exported functions that are not used nor in the white list.
    %% UWL is the unused white list and is created by the unused_white_list()
    %% function. It includes all the behaviour callbacks as well as the
    %% custom_white_list functions. You may edit custom_white_list function
    %% or add new module names to gen_events() gen_servers() and supervisors()
    %% functions to avoid very large list ouputs from this function
    %% Functions in this module are automatically whitelisted
    xref_query("UNUSED FUNCTIONS", "(UU * (Fun) my_app:App) - UWL").

to(Module, Function) ->
    to(Module, Function, "_").

to(Module, Function, Arity) when is_integer(Arity) ->
    to(Module, Function, integer_to_list(Arity));
to(Module, Function, Arity) ->
    Title = lists:flatten(io_lib:format("CALLS TO ~p:~p/~s",
					[Module, Function, Arity])),
    Query = lists:flatten(io_lib:format("E | (Fun) my_app:App || ~p:~p/~s",
					[Module, Function, Arity])),
    xref_query(Title, Query).

%% Don't put my_app_ prefix, function_regexp does that for you
gen_servers() ->
    ["conf", "facade", "worker"].

gen_events() ->
    ["logger"].

supervisors() ->
    ["supervisor"].

%% Whitelist assorted functions here
custom_white_list() ->
    "\"my_app.*\":init/1 + \"my_app.*\":debug_stop/0 "
	"+ \"my_app.*\":\"(re)?start_link\"/_ + my_app_conf:save/0 "
	"+ my_app:\"restart|terminate\"/\"0|1\" + my_app_facade:_/_".

all() ->
    undefined(),
    unresolved(),
    deprecated(),
    unused().

%%%----------------------------------------------------------------------
%%% Internal functions
%%%----------------------------------------------------------------------

load_otp() ->
    io:format("Loading OTP applications (it may take a while)...~n"),
    {ok, _} = xref:add_release(?XREF_SERVER, code:lib_dir(),
			       [{verbose, false}, {warnings, false},
				{name, otp}]).

load_my_app() ->
    io:format("Loading My_App ...~n"),
    {ok, _} = xref:add_application(?XREF_SERVER, my_app_app_path(),
				   {name, my_app}),

    io:format("Creating unused function white list ...~n"),
    unused_white_list().

unload_my_app() ->
    ok = xref:remove_application(?XREF_SERVER, my_app).

my_app_app_path() ->
    my_app_util:get_home() ++ "/ebin".

xref_query(Message, Query) ->
    {ok, L} = xref:q(?XREF_SERVER, Query),
    io:format("~n~s:~n~n", [Message]),
    print_results(L).

print_results(L) ->
    F = fun({{OMod, OFun, OAr}, {IMod, IFun, IAr}}) ->
		print_call(OMod, OFun, OAr, IMod, IFun, IAr);
	   ({Mod, Fun, Ar}) ->
		print_function(Mod, Fun, Ar)
	end,
    lists:foreach(F, L).

print_call(OMod, OFun, OAr, IMod, IFun, IAr) ->
    io:format("~p:~p/~p -> ~p:~p/~p~n", [OMod, OFun, OAr, IMod, IFun, IAr]).

print_function(Mod, Fun, Ar) ->
    io:format("~p:~p/~p~n", [Mod, Fun, Ar]).

unused_white_list() ->
    xref:forget(?XREF_SERVER, 'UWL'),
    Q = lists:flatten(["UWL:=(", module_regexp(gen_servers()), $:,
		       function_regexp(gen_server_callbacks()), "/_) "
		       "+ (", module_regexp(gen_events()), $:,
		       function_regexp(gen_event_callbacks()), "/_) "
		       "+ (", module_regexp(supervisors()), $:,
		       function_regexp(supervisor_callbacks()), "/_) "
		       "+ (", application_module(), $:,
		       function_regexp(application_callbacks()), "/_) "
		       "+ ", custom_white_list(),
		       "+ (X * (Fun) my_app_xref:Mod)"]),
    {ok, _} = xref:q(?XREF_SERVER,Q),
    ok.

module_regexp([]) ->
    "\"\"";
module_regexp([H|T]) ->
    ["\"my_app_", H, [[$|, gen_server_prefix() | Name] || Name <- T], $"].

% xemacs keeps thinking i'm writing a string until these quotes:"

function_regexp([]) ->
    "\"\"";
function_regexp([H|T]) ->
    [$", H, [[$| | Name] || Name <- T], $"].

gen_server_prefix() ->
    "my_app_".

gen_server_callbacks() ->
    ["code_change", "handle_(call(2)?|cast|info)", "init", "terminate"].

application_module() ->
    "my_app".

application_callbacks() ->
    ["start", "stop"].

gen_event_callbacks() ->
    ["init", "handle_(event|call|info)", "code_change", "terminate"].

supervisor_callbacks() ->
    ["init"].
