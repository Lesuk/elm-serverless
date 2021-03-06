module API exposing (..)

import Pipelines.Quote as Quote
import Route exposing (..)
import Serverless exposing (..)
import Serverless.Conn as Conn exposing (method, parseRoute, path, respond, updateResponse)
import Serverless.Conn.Body as Body exposing (text)
import Serverless.Conn.Request as Request exposing (Method(..))
import Serverless.Plug as Plug exposing (fork, pipeline, responder)
import Types exposing (..)


{-| A Serverless.Program is parameterized by your 3 custom types

* Config is a server load-time record of deployment specific values
* Model is for whatever you need during the processing of a request
* Msg is your app message type
-}
main : Serverless.Program Config Model Msg
main =
    Serverless.httpApi
        { configDecoder = configDecoder
        , requestPort = requestPort
        , responsePort = responsePort
        , endpoint = Endpoint
        , initialModel = Model []
        , pipeline = mainPipeline
        , subscriptions = subscriptions
        }


{-| Your pipeline.

A pipeline is a sequence of plugs, each of which transforms the connection
in some way.
-}
mainPipeline : Plug
mainPipeline =
    pipeline
        -- Simple plugs just transform the connection.
        -- A router takes a `Conn` and returns a new pipeline.
        |>
            fork router


router : Conn -> Plug
router conn =
    -- This router parses `conn.req.path` into elm data thanks to
    -- evancz/url-parser (modified for use outside of the browser).
    -- We can then match on the HTTP method and route, returning custom
    -- pipelines for each combination.
    case
        ( conn |> method
        , conn |> path |> parseRoute route NotFound
        )
    of
        ( GET, Home ) ->
            -- responder can quickly create a loop plug which sends a response
            responder responsePort <|
                \_ -> ( 200, text "Home" )

        ( method, Quote lang ) ->
            -- Notice that we are passing part of the router result
            -- (i.e. `lang`) into `loadQuotes`.
            Quote.router method lang

        ( GET, Buggy ) ->
            responder responsePort <|
                \_ -> ( 500, text "bugs, bugs, bugs" )

        ( _, NotFound ) ->
            -- use this form of responder when you need to access the conn
            responder responsePort <|
                \conn -> ( 404, text <| (++) "Nothing at: " <| path conn )

        _ ->
            responder responsePort <|
                \conn -> ( 405, text "Method not allowed" )



-- SUBSCRIPTIONS


subscriptions : Conn -> Sub Msg
subscriptions _ =
    Sub.none
