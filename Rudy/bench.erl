-module(bench).
-export([bench/2]).

bench(Host, Port) ->
    StartTime = erlang:system_time(millisecond),
    run(100, Host, Port),
    EndTime = erlang:system_time(millisecond),
    Duration = EndTime - StartTime,
    io:format("Time taken for 100 requests: ~p milliseconds~n", [Duration]).

run(N, Host, Port) ->
    if N == 0 ->
        ok;
    true ->
        request(Host, Port),
        run(N - 1, Host, Port)
    end.

request(Host, Port) ->
    Opt = [list, {active, false}, {reuseaddr, true}],
    {ok, ServerSocket} = gen_tcp:connect(Host, Port, Opt),
    gen_tcp:send(ServerSocket, http:get("foo")),
    Recv = gen_tcp:recv(ServerSocket, 0),
    case Recv of
        {ok, _} ->
            ok;
        {error, Error} ->
            io:format("bench: error: ~w~n", [Error])
    end,
    gen_tcp:close(ServerSocket).