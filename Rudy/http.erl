-module(http).
-export([parse_req/1, ok/1, get/1]).

% Parse the request line, headers, and remaining body in order.
parse_req(R0) ->
    {Request, R1} = req_line(R0),
    {Headers, R2} = headers(R1),
    {Body, _} = msg_body(R2),
    {Request, Headers, Body}.

% Parse a request line that starts with the GET method.
req_line([$G, $E, $T, 32 | R0]) ->
    {URI, R1} = req_uri(R0),
    {Version, R2} = http_version(R1),
    %pattern matching the CRLF at the end of the request line
    [13, 10 | R3] = R2,
    {{get, URI, Version}, R3}.

% TODO: Add support for other HTTP methods (POST, PUT, DELETE, etc.).
% 
% TODO: If not \r\n, return an error or handle the error appropriately.
% 
% TODO: concenate request if the request is split across multiple packets.


% A space terminates the URI and leaves the rest for HTTP version parsing.
req_uri([32 | R0]) ->
    {[], R0};
% Consume one URI character and recursively parse the remainder.
req_uri([C | R0]) ->
    {RestURI, R1} = req_uri(R0),
    {[C | RestURI], R1}.
%TODO: make this tail recursive, build up URI as we go and return it when done.
% 
%TODO: Parse the URI into its components (path, query string, etc.) and return them as a tuple instead of just a list of characters. This will make it easier to handle the request later on.
% 
% Recognize the HTTP versions supported by this small parser.
http_version([$H, $T, $T, $P, $/, $1, $., $1 | R0]) ->
    {http_1_1, R0};
http_version([$H, $T, $T, $P, $/, $1, $., $0 | R0]) ->
    {http_1_0, R0};
http_version(_) ->
    {error, unsupported_http_version}.



% An empty line marks the end of the header block.
headers([13, 10 | R0]) ->
    {[], R0};
% Parse one header and continue until the blank line is reached.
headers(R0) ->
    {Header, R1} = header(R0),
    {RestHeaders, R2} = headers(R1),
    {[Header | RestHeaders], R2}.

% A CRLF terminates the current header.
header([13, 10 | R0]) ->
    {[], R0};
% Consume one header character and recursively parse the remainder.
header([C | R0]) ->
    {RestHeader, R1} = header(R0),
    {[C | RestHeader], R1}.

% The parser currently treats all remaining data as the body without decoding it.
msg_body(R0) ->
    {R0, []}.

% Build the minimal successful HTTP response used by the server.
ok(Body) ->
    "HTTP/1.1 200 OK\r\n" ++ "\r\n" ++ Body.

% Build a simple HTTP/1.1 GET request for the benchmark client.
get(URI) ->
    "GET " ++ URI ++ " HTTP/1.1\r\n" ++ "\r\n".