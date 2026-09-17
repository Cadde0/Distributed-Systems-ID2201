-module(tic).
-export([first/0]).

% Wait for the first message in the tic-tac-toe sequence.
first() ->
    receive
        {tic, X} ->
            io:format("tic: ~w~n", [X]),
            second()
        end.

% After tic, accept either tac or toe and then finish the sequence.
second() ->
    receive
        {tac, X} ->
            io:format("tac: ~w~n", [X]),
            last();
        {toe, X} ->
            io:format("toe: ~w~n", [X]),
            last()
    end.

% Accept and print any final message, regardless of its shape.
last() ->
    receive
        X -> 
            io:format("end: ~w~n", [X])
    end.