-module(intf).
-export([new/0, add/4, remove/2, lookup/2, ref/2, name/2, list/1, broadcast/2]).

% The interface is a list of {neighbor_name, monitor_ref, neighbor_pid} tuples.
new() ->
    [].

% Add or replace a neighbor entry while keeping names unique.
add(Name, Ref, Pid, Intf) ->
    [{Name, Ref, Pid} | lists:keydelete(Name, 1, Intf)].

% Remove a neighbor by name.
remove(Name, Intf) ->
    lists:keydelete(Name, 1, Intf).

% Find the process identifier associated with a neighbor name.
lookup(Name, Intf) ->
    case lists:keyfind(Name, 1, Intf) of
        {Name, _Ref, Pid} ->
            {ok, Pid};
        false ->
            notfound
    end.

% Find the monitor reference associated with a neighbor name.
ref(Name, Intf) ->
    case lists:keyfind(Name, 1, Intf) of
        {Name, Ref, _Pid} ->
            {ok, Ref};
        false ->
            notfound
    end.

% Find the neighbor name associated with a monitor reference.
name(Ref, Intf) ->
    case lists:keyfind(Ref, 2, Intf) of
        {Name, Ref, _Pid} ->
            {ok, Name};
        false ->
            notfound
    end.

% Return only the names of currently known neighbors.
list(Intf) ->
    [Name || {Name, _Ref, _Pid} <- Intf].

% Send one message to every neighbor process.
broadcast(Message, Intf) ->
    lists:foreach(
        fun({_Name, _Ref, Pid}) ->
            Pid ! Message
        end,
        Intf
    ).