-module(dijkstra).
-export([entry/2, replace/4, update/4, iterate/3, table/2, route/2]).

% Return a node's distance from the sorted work list, or zero if absent.
entry(Node, Sorted) ->
    case lists:keyfind(Node, 1, Sorted) of
        {Node, N, _Gateway} ->
            N;
        false ->
            0
    end.

% Replace a node's candidate route and keep candidates ordered by distance.
replace(Node, N, Gateway, Sorted) ->
    Removed = lists:keydelete(Node, 1, Sorted),
    lists:keysort(2, [{Node, N, Gateway} | Removed]).

% Improve a candidate only when the new path is shorter.
update(Node, N, Gateway, Sorted) ->
    case lists:keyfind(Node, 1, Sorted) of
        false ->
            Sorted;
        {Node, Old, _} when N < Old ->
            replace(Node, N, Gateway, Sorted);
        {Node, _, _} ->
            Sorted
    end.

% Exhaust the candidate list or stop when the closest remaining node is unreachable.
iterate([], _Map, Table) ->
    Table;

iterate([{_, inf, _} | _Rest], _Map, Table) ->
    Table;

iterate([{Node, N, Gateway} | Rest], Map, Table) ->
    % Relax every outgoing edge from the closest candidate.
    Neighbors = map:reachable(Node, Map),
    NewSorted = lists:foldl(
        fun(Neighbor, Sorted) ->
            update(Neighbor, N + 1, Gateway, Sorted)
        end,
        Rest,
        Neighbors
    ),
iterate(NewSorted, Map, [{Node, Gateway} | Table]).

% Build a shortest-path table from the directly connected gateway nodes.
table(Gateways, Map) ->
    Nodes = map:all_nodes(Map),
    Initial = lists:map(
        fun(Node) ->
            case lists:member(Node, Gateways) of
                true ->
                    {Node, 0, Node};
                false ->
                    {Node, inf, unknown}
            end
        end,
        Nodes
    ),
    iterate(lists:keysort(2, Initial), Map, []).

% Look up the first gateway to use when forwarding toward Node.
route(Node, Table) ->
    case lists:keyfind(Node, 1, Table) of
        {Node, Gateway} ->
            {ok, Gateway};
        false ->
            notfound
    end.