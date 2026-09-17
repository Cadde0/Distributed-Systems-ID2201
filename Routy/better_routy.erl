-module(better_routy).
-export([start/2, stop/1]).

% Start a router process and register it under Reg.
start(Reg, Name) ->
    register(Reg, spawn(fun() -> init(Name) end)).

% Ask the router to stop and remove its registration.
stop(Node) ->
    Node ! stop,
    unregister(Node).

% Initialize all state used by the link-state router.
init(Name) ->
    Intf = intf:new(),
    Map = map:new(),
    Table = dijkstra:table(Intf, Map),
    Hist = hist:new(Name),
    router(Name, 0, Hist, Intf, Table, Map).

router(Name, N, Hist, Intf, Table, Map) ->
    receive
        {add, Node, Pid} ->
            % Neighbor changes immediately trigger a new link-state advertisement.
            Ref = erlang:monitor(process, Pid),
            Intf1 = intf:add(Node, Ref, Pid, Intf),
            broadcast_links(Name, N, Intf1),
            router(Name, N+1, Hist, Intf1, Table, Map);

        {remove, Node} ->
            % Explicit removals are advertised just like detected failures.
            {ok, Ref} = intf:ref(Node, Intf),
            erlang:demonitor(Ref),
            Intf1 = intf:remove(Node, Intf),
            broadcast_links(Name, N, Intf1),
            router(Name, N+1, Hist, Intf1, Table, Map);

        {'DOWN', Ref, process, _, _} ->
            % A monitor DOWN message removes a failed neighbor and advertises the change.
            {ok, Down} = intf:name(Ref, Intf),
            io:format("~w: exit received from ~w~n", [Name, Down]),
            Intf1 = intf:remove(Down, Intf),
            broadcast_links(Name, N, Intf1),
            router(Name, N+1, Hist, Intf1, Table, Map);

        {links, Node, R, Links} ->
            % New advertisements update both the topology map and route table.
            case hist:update(Node, R, Hist) of
                {new, Hist1} ->
                    intf:broadcast({links, Node, R, Links}, Intf),
                    Map1 = map:update(Node, Links, Map),
                    Table1 = dijkstra:table(intf:list(Intf), Map1),
                    router(Name, N, Hist1, Intf, Table1, Map1);
                old ->
                    router(Name, N, Hist, Intf, Table, Map)
            end;

        update ->
            % Recompute routes using the latest topology information.
            Table1 = dijkstra:table(intf:list(Intf), Map),
            router(Name, N, Hist, Intf, Table1, Map);

        broadcast ->
            % Send this router's current neighbor list to all neighbors.
            broadcast_links(Name, N, Intf),
            router(Name, N+1, Hist, Intf, Table, Map);

        {route, Name, From, Message} ->
            io:format("~w: received message ~s from ~w~n", [Name, Message, From]),
            router(Name, N, Hist, Intf, Table, Map);

        {route, To, From, Message} ->
            % Forward a message to the first gateway on the shortest known route.
            io:format("~w: routing message (~s)~n", [Name, Message]),
            case dijkstra:route(To, Table) of
                {ok, Gw} ->
                    case intf:lookup(Gw, Intf) of
                        {ok, Pid} ->
                            Pid ! {route, To, From, Message};
                        notfound ->
                            ok
                    end;
                notfound ->
                    ok
            end,
            router(Name, N, Hist, Intf, Table, Map);

        {send, To, Message} ->
            % Start routing locally by sending the message to this router's mailbox.
            self() ! {route, To, Name, Message},
            router(Name, N, Hist, Intf, Table, Map);

        {status, From} ->
            From ! {status, {Name, N, Hist, Intf, Table, Map}},
            router(Name, N, Hist, Intf, Table, Map);

        stop ->
            % Returning from the receive loop terminates the process.
            ok
    end.

% Construct and flood this router's current link-state advertisement.
broadcast_links(Name, N, Intf) ->
    Message = {links, Name, N, intf:list(Intf)},
    intf:broadcast(Message, Intf).