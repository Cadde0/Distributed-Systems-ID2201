-module(routy).
-export([start/2, stop/1]).

% Start a router process and register it under Reg.
start(Reg, Name) ->
    register(Reg, spawn(fun() -> init(Name) end)).

% Ask a router to stop, then remove its local registration.
stop(Node) ->
    Node ! stop,
    unregister(Node).

% Create the router's initial interface, topology map, history, and route table.
init(Name) ->
    Intf = intf:new(),
    Map = map:new(),
    Table = dijkstra:table(Intf, Map),
    Hist = hist:new(Name),
    router(Name, 0, Hist, Intf, Table, Map).

router(Name, N, Hist, Intf, Table, Map) ->
    receive
        {add, Node, Pid} ->
            % Monitor neighbors so crashes can remove stale interface entries.
            Ref = erlang:monitor(process, Pid),
            Intf1 = intf:add(Node, Ref, Pid, Intf),
            router(Name, N, Hist, Intf1, Table, Map);

        {remove, Node} ->
            {ok, Ref} = intf:ref(Node, Intf),
            erlang:demonitor(Ref),
            Intf1 = intf:remove(Node, Intf),
            router(Name, N, Hist, Intf1, Table, Map);

        {'DOWN', Ref, process, _, _} ->
            {ok, Down} = intf:name(Ref, Intf),
            io:format("~w: exit received from ~w~n", [Name, Down]),
            Intf1 = intf:remove(Down, Intf),
            router(Name, N, Hist, Intf1, Table, Map);

        {links, Node, R, Links} ->
            % Flood only link-state advertisements that have not been seen before.
            case hist:update(Node, R, Hist) of
                {new, Hist1} ->
                    intf:broadcast({links, Node, R, Links}, Intf),
                    Map1 = map:update(Node, Links, Map),
                    router(Name, N, Hist1, Intf, Table, Map1);
                old ->
                    router(Name, N, Hist, Intf, Table, Map)
            end;

        update ->
            % Recompute shortest paths from the latest known topology.
            Table1 = dijkstra:table(intf:list(Intf), Map),
            router(Name, N, Hist, Intf, Table1, Map);

        broadcast ->
            % Advertise this router's current direct neighbors.
            Message = {links, Name, N, intf:list(Intf)},
            intf:broadcast(Message, Intf),
            router(Name, N+1, Hist, Intf, Table, Map);

        {route, Name, From, Message} ->
            io:format("~w: received message ~s from ~w~n", [Name, Message, From]),
            router(Name, N, Hist, Intf, Table, Map);

        {route, To, From, Message} ->
            % Forward through the gateway selected by the current routing table.
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
            % Convert a local send request into the same route message used by forwarding.
            self() ! {route, To, Name, Message},
            router(Name, N, Hist, Intf, Table, Map);

        {status, From} ->
            From ! {status, {Name, N, Hist, Intf, Table, Map}},
            router(Name, N, Hist, Intf, Table, Map);

        stop ->
            % Returning from the receive loop terminates the router process.
            ok
    end.