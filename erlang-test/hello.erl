-module(hello).
-export([hello/0]).

% Print a greeting to standard output.
hello() ->
    io:format("Hello, World!~n").