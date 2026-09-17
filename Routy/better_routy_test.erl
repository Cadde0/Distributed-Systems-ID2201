-module(better_routy_test).
-export([run/0, failure_test/0, stop/0]).

% Stop all named test routers before starting a fresh test topology.
stop() ->
    Names = [stockholm, lund, malmo, goteborg, uppsala],
    lists:foreach(
        fun(N) ->
            case whereis(N) of
                undefined -> ok;
                _Pid ->
                    try
                        better_routy:stop(N)
                    catch
                        _:_ -> ok
                    end
            end
        end,
        Names
    ),
    ok.

% Start the improved routers and verify that link changes advertise automatically.
run() ->
    stop(),
    timer:sleep(100),

    better_routy:start(stockholm, stockholm),
    better_routy:start(lund, lund),
    better_routy:start(malmo, malmo),
    better_routy:start(goteborg, goteborg),
    better_routy:start(uppsala, uppsala),

    timer:sleep(200),

    stockholm ! {add, lund, {lund, node()}},
    lund ! {add, stockholm, {stockholm, node()}},
    lund ! {add, malmo, {malmo, node()}},
    malmo ! {add, lund, {lund, node()}},
    malmo ! {add, goteborg, {goteborg, node()}},
    goteborg ! {add, malmo, {malmo, node()}},
    goteborg ! {add, uppsala, {uppsala, node()}},
    uppsala ! {add, goteborg, {goteborg, node()}},

    timer:sleep(500),

    io:format("~n--- Sending stockholm -> uppsala ---~n"),
    stockholm ! {send, uppsala, "hello from stockholm"},
    timer:sleep(200),
    ok.

% Kill a middle router and inspect the route table before and after recovery.
failure_test() ->
    io:format("~n=== FAILURE SCENARIO (better_routy): killing malmo ===~n"),

    stockholm ! {status, self()},
    receive
        {status, {_, _, _, _, Table0, _}} ->
            io:format("stockholm's route to uppsala BEFORE kill: ~p~n",
                      [dijkstra:route(uppsala, Table0)])
    after 1000 -> io:format("no status reply~n") end,

    exit(whereis(malmo), kill),

    io:format("~nWaiting for self-healing propagation...~n"),
    timer:sleep(500),

    stockholm ! {status, self()},
    receive
        {status, {_, _, _, _, Table1, _}} ->
            io:format("stockholm's route to uppsala AFTER kill: ~p~n",
                      [dijkstra:route(uppsala, Table1)])
    after 1000 -> io:format("no status reply~n") end,

    io:format("~nSending stockholm -> uppsala after kill (should print nothing, dropped cleanly)~n"),
    stockholm ! {send, uppsala, "still there?"},
    timer:sleep(200),

    ok.