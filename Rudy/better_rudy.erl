-module(better_rudy).
-export([start/1, stop/0]).

start(Port) ->
    %Start the server in a new process so we can stop it later.
    % register names the Pid "rudy"
    % spawn creates an independent process that runs the init().
    register(rudy, spawn(fun() -> init(Port) end)).

stop() ->
    %Stop the server by sending a message to the process that is running the server.

    exit(whereis(rudy), "Time to die").
%TODO make a better stop function that lets processes finish before shutdown.

init(Port) ->
    %Deliver as list so we can pattern match on it
    % active false means we will have to explicitly call gen_tcp:recv to get data from the socket
    % reuseaddr true allows us to reuse the port if the server is restarted quickly
    Opt = [list, {active, false}, {reuseaddr, true}],
    case gen_tcp:listen(Port, Opt) of
        {ok, ListenSocket} ->
            handle_connections(ListenSocket),
            gen_tcp:close(ListenSocket),
            ok;
        {error, Error} ->
            io:format("Failed to listen on port ~p: ~w~n", [Port, Error])
    end.

handle_connections(ListenSocket) ->
    %gen_tcp:accept will block until a new connection is made, so we can just call it in a loop to handle multiple connections.
    case gen_tcp:accept(ListenSocket) of
        %When a a client connects, a new socket is created for that client, and we can use that socket to communicate with the client.
        {ok, ClientSocket} ->
            
            spawn(fun() -> handle_better_request(ClientSocket) end),
            handle_connections(ListenSocket);
        {error, Error} ->
            io:format("Failed to accept connection: ~w~n", [Error])
    end.


handle_better_request(ClientSocket) ->
    Data = read_req(ClientSocket, []),
    
    case Data of
        {ok, Str} ->
            Request = http:parse_req(Str),
            Response = handle_response(Request),
            gen_tcp:send(ClientSocket, Response);
        {error, Error} ->
            io:format("rudy: error: ~w~n", [Error])
    end,
    gen_tcp:close(ClientSocket).


read_req(ClientSocket, Acc) ->
    case find_header_end(Acc) of
        true ->
            {ok, Acc};
        false ->
            case gen_tcp:recv(ClientSocket, 0) of
                {ok, Chunk} ->
                    read_req(ClientSocket, Acc ++ Chunk);
                {error, Error} ->
                    {error, Error}
            end
    end.

find_header_end(Str) ->
    case string:str(Str, "\r\n\r\n") of
        0 -> false;
        _ -> true
    end.

handle_response({{get, URI, _Version}, _Headers, _Body}) ->
    timer:sleep(40), %simulate some processing time, 40ms
    http:ok("Hello " ++ URI).