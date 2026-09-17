-module(map).

-export([new/0, update/3, reachable/2, all_nodes/1]).

new() ->
    [].

% Replace the advertised outgoing links for one node.
update(Node, Links, Map) ->
    [{Node, Links} | lists:keydelete(Node, 1, Map)].

% Return a node's outgoing links, or no links for an unknown node.
reachable(Node, Map) ->
    case lists:keyfind(Node, 1, Map) of
        {Node, Links} ->
            Links;
        false ->
            []
    end.

% Include both advertised nodes and nodes that appear only as link targets.
all_nodes(Map) ->
    Nodes = [Node || {Node, _Links} <- Map],
    Targets = lists:append([Links || {_Node, Links} <- Map]),
    lists:usort(Nodes ++ Targets).
