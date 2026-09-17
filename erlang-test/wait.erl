-module(wait).
-export([hello/0]).

% Block until one message arrives, then print it as a string.
hello() ->
    receive
        X -> io:format("aaa! surprise, a message: ~s~n", [X])
    end.

