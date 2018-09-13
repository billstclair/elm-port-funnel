----------------------------------------------------------------------
--
-- Echo.elm
-- The Elm frontend for the site/js/PortFunnel/Echo.js backend.
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE.txt
--
----------------------------------------------------------------------


module PortFunnel.Echo exposing
    ( Message(..), Response(..), State
    , moduleName, moduleDesc, commander
    , initialState
    , makeMessage, send
    , toString, toJsonString
    , makeSimulatedCmdPort
    , isLoaded, findMessages, stateToStrings
    )

{-| An example echo funnel, with a simulator.


# Types

@docs Message, Response, State


# Components of a `PortFunnel.FunnelSpec`

@docs moduleName, moduleDesc, commander


# Initial `State`

@docs initialState


# Sending a `Message` out the `Cmd` Port

@docs makeMessage, send


# Conversion to Strings

@docs toString, toJsonString


# Simulator

@docs makeSimulatedCmdPort


# Non-standard Functions

@docs isLoaded, findMessages, stateToStrings

-}

import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (GenericMessage, ModuleDesc)


{-| Our internal state.

Just tracks all incoming messages.

-}
type State
    = State
        { isLoaded : Bool
        , messages : List Message
        }


{-| Returns true if a `Startup` message has been processed.

This is sent by the port code after it has initialized.

-}
isLoaded : State -> Bool
isLoaded (State state) =
    state.isLoaded


{-| A `MessageResponse` encapsulates a message.

`NoResponse` is currently unused, but many PortFunnel-aware modules will need it.

`CmdResponse` denotes a message that needs to be sent through the port. This is done by the `commander` function.

`ListResponse` allows us to return multiple responses. `commander` descends a `ListResponse` looking for `CmdResponse` responses. `findMessages` descends a list of `Response` records, collecting the `MessageResponse` messages.

-}
type Response
    = NoResponse
    | MessageResponse Message
    | CmdResponse Message
    | ListResponse (List Response)


{-| Since this is a simple echo example, the messages are just strings.
-}
type Message
    = Request String
    | Startup


{-| The initial, empty state, so the application can initialize its state.
-}
initialState : State
initialState =
    State
        { isLoaded = False
        , messages = []
        }


{-| The name of this module: "Echo".
-}
moduleName : String
moduleName =
    "Echo"


{-| Our module descriptor.
-}
moduleDesc : ModuleDesc Message State Response
moduleDesc =
    PortFunnel.makeModuleDesc moduleName encode decode process


encode : Message -> GenericMessage
encode message =
    case message of
        Request string ->
            GenericMessage moduleName "request" <| JE.string string

        Startup ->
            GenericMessage moduleName "startup" JE.null


decode : GenericMessage -> Result String Message
decode { tag, args } =
    case tag of
        "request" ->
            case JD.decodeValue JD.string args of
                Ok string ->
                    Ok (Request string)

                Err _ ->
                    Err <|
                        "Echo args not a string: "
                            ++ JE.encode 0 args

        "startup" ->
            Ok Startup

        _ ->
            Err <| "Unknown Echo tag: " ++ tag


{-| Send a `Message` through a `Cmd` port.
-}
send : (Value -> Cmd msg) -> Message -> Cmd msg
send =
    PortFunnel.sendMessage moduleDesc


process : Message -> State -> ( State, Response )
process message (State state) =
    case message of
        Startup ->
            ( State { state | isLoaded = True }
            , NoResponse
            )

        Request string ->
            let
                beginsDollar =
                    String.left 1 string == "$"

                response =
                    MessageResponse message
            in
            ( State
                { state
                    | messages = message :: state.messages
                }
            , if beginsDollar then
                ListResponse
                    [ response
                    , CmdResponse (Request <| String.dropLeft 1 string)
                    ]

              else
                response
            )


{-| Responsible for sending a `CmdResponse` back througt the port.

Called by `PortFunnel.appProcess` for each response returned by `process`.

-}
commander : (GenericMessage -> Cmd msg) -> Response -> Cmd msg
commander gfPort response =
    case response of
        CmdResponse message ->
            encode message
                |> gfPort

        ListResponse messages ->
            List.foldl
                (\resp cmds ->
                    Cmd.batch
                        [ commander gfPort resp
                        , cmds
                        ]
                )
                Cmd.none
                messages

        _ ->
            Cmd.none


simulator : Message -> Maybe Message
simulator message =
    case message of
        Request string ->
            Just (Request <| string ++ " (simulated)")

        Startup ->
            Nothing


{-| Make a simulated `Cmd` port.
-}
makeSimulatedCmdPort : (Value -> msg) -> Value -> Cmd msg
makeSimulatedCmdPort =
    PortFunnel.makeSimulatedFunnelCmdPort
        moduleDesc
        simulator


{-| When it needs to send the tail of a message beginning with a dollar sign

through the port, the `Echo` module returns a `ListResponse`. This function recursively descends a ListResponse, and returns a list of the `Message`s from any `MessageResponse`s it finds.

-}
findMessages : List Response -> List Message
findMessages responses =
    List.foldr
        (\response res ->
            case response of
                MessageResponse message ->
                    message :: res

                ListResponse resps ->
                    List.append
                        (findMessages resps)
                        res

                _ ->
                    res
        )
        []
        responses


{-| Convert a `Message` to a nice-looking human-readable string.
-}
toString : Message -> String
toString message =
    case message of
        Request string ->
            string

        Startup ->
            "<Startup>"


{-| Convert a `Message` to the same JSON string that gets sent

over the wire to the JS code.

-}
toJsonString : Message -> String
toJsonString message =
    message
        |> encode
        |> PortFunnel.encodeGenericMessage
        |> JE.encode 0


{-| Make a message to send out through the port.
-}
makeMessage : String -> Message
makeMessage string =
    Request string


{-| Convert our `State` to a list of strings.
-}
stateToStrings : State -> List String
stateToStrings (State state) =
    List.map toJsonString state.messages
