-module(routy_test).
-export([run/0, failure_test/0, stop/0]).

% Build a five-router chain, exchange topology information, and send messages.
run() ->
    %% Start five routers, registered under their own city name for simplicity
    routy:start(stockholm, stockholm),
    routy:start(lund, lund),
    routy:start(malmo, malmo),
    routy:start(goteborg, goteborg),
    routy:start(uppsala, uppsala),

    timer:sleep(200),

    %% Wire up a chain: stockholm - lund - malmo - goteborg - uppsala
    %% add/3 is one-directional, so we add both ends of every link
    stockholm ! {add, lund, {lund, node()}},
    lund ! {add, stockholm, {stockholm, node()}},

    lund ! {add, malmo, {malmo, node()}},
    malmo ! {add, lund, {lund, node()}},

    malmo ! {add, goteborg, {goteborg, node()}},
    goteborg ! {add, malmo, {malmo, node()}},

    goteborg ! {add, uppsala, {uppsala, node()}},
    uppsala ! {add, goteborg, {goteborg, node()}},

    timer:sleep(200),

    %% Everyone announces their links
    stockholm ! broadcast,
    lund ! broadcast,
    malmo ! broadcast,
    goteborg ! broadcast,
    uppsala ! broadcast,

    timer:sleep(500), % give link-state flooding time to settle

    %% Everyone recomputes their routing table
    stockholm ! update,
    lund ! update,
    malmo ! update,
    goteborg ! update,
    uppsala ! update,

    timer:sleep(200),

    io:format("~n--- Sending stockholm -> uppsala (3 hops expected) ---~n"),
    stockholm ! {send, uppsala, "hello from stockholm"},

    timer:sleep(200),

    io:format("~n--- Sending uppsala -> stockholm (reverse direction) ---~n"),
    uppsala ! {send, stockholm, "hello from uppsala"},

    timer:sleep(200),

    io:format("~n--- Sending lund -> goteborg (2 hops expected) ---~n"),
    lund ! {send, goteborg, "hello from lund"},

    timer:sleep(200),

    io:format("~n--- Checking status of malmo ---~n"),
    malmo ! {status, self()},
    receive
        {status, S} ->
            io:format("malmo status: ~p~n", [S])
    after 1000 ->
        io:format("no status reply~n")
    end,

    ok.

% Stop every router used by the tests, ignoring already-stopped nodes.
stop() ->
    Names = [stockholm, lund, malmo, goteborg, uppsala],
    lists:foreach(
        fun(N) ->
            case whereis(N) of
                undefined ->
                    ok;
                _Pid ->
                    try
                        routy:stop(N)
                    catch
                        _:_ -> ok
                    end
            end
        end,
        Names
    ),
    ok.

% Kill a middle router and observe monitor-driven interface cleanup.
failure_test() ->
    io:format("~n=== FAILURE SCENARIO: killing malmo ===~n"),

    io:format("~nBefore: stockholm -> uppsala~n"),
    stockholm ! {send, uppsala, "still connected"},
    timer:sleep(200),

    %% Kill malmo's process directly (simulates a crash, not a graceful stop)
    exit(whereis(malmo), kill),

    io:format("~nWaiting for 'DOWN' messages to propagate...~n"),
    timer:sleep(500),

    io:format("~nAfter kill: stockholm -> uppsala (chain is broken, no alt path)~n"),
    stockholm ! {send, uppsala, "still there?"},
    timer:sleep(200),

    io:format("~nChecking lund's interfaces (should have dropped malmo)~n"),
    lund ! {status, self()},
    receive
        {status, {Name, _N, _Hist, Intf, _Table, _Map}} ->
            io:format("~w interfaces: ~w~n", [Name, intf:list(Intf)])
    after 1000 ->
        io:format("no status reply~n")
    end,

    io:format("~nChecking goteborg's interfaces (should have dropped malmo)~n"),
    goteborg ! {status, self()},
    receive
        {status, {Name2, _N2, _Hist2, Intf2, _Table2, _Map2}} ->
            io:format("~w interfaces: ~w~n", [Name2, intf:list(Intf2)])
    after 1000 ->
        io:format("no status reply~n")
    end,

    ok.
