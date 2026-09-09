-module(rudy).
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
            %Handles one connection at a time, but we can easily change this to handle multiple connections by spawning a new process for each connection.
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
            %spawn(fun() -> handle_request(ClientSocket) end),
            handle_request(ClientSocket),
            handle_connections(ListenSocket);
        {error, Error} ->
            io:format("Failed to accept connection: ~w~n", [Error])
    end.

handle_request(ClientSocket) ->
    %We use gen_tcp:recv to receive data from the client socket. The second argument is the number of bytes to receive, 0 means we want to receive all available data.
    Recv = gen_tcp:recv(ClientSocket, 0),
    case Recv of
        {ok, Data} ->
            Request = http:parse_req(Data),
            Response = handle_response(Request),
            gen_tcp:send(ClientSocket, Response);
        {error, Error} ->
            io:format("rudy: error: ~w~n", [Error])
    end,
    gen_tcp:close(ClientSocket).



handle_response({{get, URI, _Version}, _Headers, _Body}) ->
    timer:sleep(40), %simulate some processing time, 40ms
    http:ok("Hello " ++ URI).