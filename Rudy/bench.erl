-module(bench).
-export([bench/2, pbench/3, frag_test/2]).

% Run 100 sequential requests and report the elapsed time.
bench(Host, Port) ->
    StartTime = erlang:system_time(millisecond),
    run(100, Host, Port),
    EndTime = erlang:system_time(millisecond),
    Duration = EndTime - StartTime,
    io:format("Time taken for 100 requests: ~p milliseconds~n", [Duration]).

% Run 100 requests per client process and measure concurrent throughput.
pbench(Host, Port, Clients) ->
    Self = self(),
    StartTime = erlang:system_time(millisecond),
    Pids = [spawn(fun() -> run(100, Host, Port), Self ! done end) || _ <- lists:seq(1, Clients)],
    [receive done -> ok end || _ <- Pids],
    EndTime = erlang:system_time(millisecond),
    Duration = EndTime - StartTime,
    io:format("Time taken for ~p requests: ~p milliseconds~n", [Clients * 100, Duration]).

% Repeat the request operation N times.
run(N, Host, Port) ->
    if N == 0 ->
        ok;
    true ->
        request(Host, Port),
        run(N - 1, Host, Port)
    end.

% Open a connection, send one GET request, receive the response, and close it.
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

% Verify that the server handles a request split across two TCP sends.
frag_test(Host, Port) ->
    Opt = [list, {active, false}, {reuseaddr, true}],
    {ok, Server} = gen_tcp:connect(Host, Port, Opt),
    Request = http:get("foo"),
    {Part1, Part2} = lists:split(5, Request),
    gen_tcp:send(Server, Part1),
    timer:sleep(200),
    gen_tcp:send(Server, Part2),
    Recv = gen_tcp:recv(Server, 0),
    gen_tcp:close(Server),
    Recv.