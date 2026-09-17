-module(hist).
-export([new/1, update/3]).

% Seed the history with this router's own initial sequence number.
new(Name) ->
    [{Name, inf}].

% Accept a link-state update only when it is newer than the stored version.
update(Node, N, History) ->
    case lists:keyfind(Node, 1, History) of
        false ->
            {new, [{Node, N} | History]};
        {Node, Max} when N > Max ->
            {new, [{Node, N} | lists:keydelete(Node, 1, History)]};
        {Node, _Max} ->
            old
    end.