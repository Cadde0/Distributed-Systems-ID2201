-module(http).
-export([parse_req/1, ok/1, get/1]).

parse_req(R0) ->
    {Request, R1} = req_line(R0),
    {Headers, R2} = headers(R1),
    {Body, _} = msg_body(R2),
    {Request, Headers, Body}.


%pattern matching "GET_" in the input
req_line([$G, $E, $T, 32 | R0]) ->
    {URI, R1} = req_uri(R0),
    {Version, R2} = http_version(R1),
    %pattern matching the CRLF at the end of the request line
    [13, 10 | R3] = R2,
    {{get, URI, Version}, R3}.
%TODO: Add support for other HTTP methods (POST, PUT, DELETE, etc.)
% 
% TODO: If not \r\n, return an error or handle the error appropriately.
% 
% TODO: concenate request if the request is split across multiple packets.


%Base case, when the next character is a space(32), the URI is done.
req_uri([32 | R0]) ->
    {[], R0};
%Recursive Case, when the next character is not a space(32), we add it to the URI and continue parsing.
req_uri([C | R0]) ->
    {RestURI, R1} = req_uri(R0),
    {[C | RestURI], R1}.
%TODO: make this tail recursive, build up URI as we go and return it when done.
% 
%TODO: Parse the URI into its components (path, query string, etc.) and return them as a tuple instead of just a list of characters. This will make it easier to handle the request later on.
% 
%Checks for HTTP/1.1 or HTTP/1.0 otherwise throws an error
http_version([$H, $T, $T, $P, $/, $1, $., $1 | R0]) ->
    {http_1_1, R0};
http_version([$H, $T, $T, $P, $/, $1, $., $0 | R0]) ->
    {http_1_0, R0};
http_version(_) ->
    {error, unsupported_http_version}.



%Collect chars until we hit a \r\n blank line, which indicates the end of the headers section.
headers([13, 10 | R0]) ->
    {[], R0};
%Recursive case, when the next two characters are not \r\n, we parse the next header and continue parsing.
headers(R0) ->
    {Header, R1} = header(R0),
    {RestHeaders, R2} = headers(R1),
    {[Header | RestHeaders], R2}.

%Base case, when the next two characters are \r\n, the header is done.
header([13, 10 | R0]) ->
    {[], R0};
%Recursive case, when the next two characters are not \r\n, we add the next character to the header and continue parsing.
header([C | R0]) ->
    {RestHeader, R1} = header(R0),
    {[C | RestHeader], R1}.

%"The rest is body" - we don't care about the body for now, so we just return an empty list. Maybe fix this later
msg_body(R0) ->
    {R0, []}.

ok(Body) ->
    "HTTP/1.1 200 OK\r\n" ++ "\r\n" ++ Body.

get(URI) ->
    "GET " ++ URI ++ " HTTP/1.1\r\n" ++ "\r\n".