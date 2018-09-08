----------------------------------------------------------------------
--
-- AddXY.elm
-- The Elm frontend for the site/js/PortFunnel/AddXY.js backend.
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE.txt
--
----------------------------------------------------------------------


module PortFunnel.AddXY exposing
    ( Message(..), Response(..), State
    , moduleName, moduleDesc, commander
    , initialState
    , makeAddMessage, makeMultiplyMessage, send
    , toString, toJsonString
    , makeSimulatedCmdPort
    , stateToStrings
    )

{-| An example add/multiply funnel, with a simulator.


# Types

@docs Message, Response, State


# Components of a `PortFunnel.FunnelSpec`

@docs moduleName, moduleDesc, commander


# Initial `State`

@docs initialState


# Sending a `Message` out the `Cmd` Port

@docs makeAddMessage, makeMultiplyMessage, send


# Conversion to Strings

@docs toString, toJsonString


# Simulator

@docs makeSimulatedCmdPort


# Non-standard Functions

@docs stateToStrings

-}

import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (GenericMessage, ModuleDesc)


type alias Question =
    { x : Int
    , y : Int
    }


type alias Answer =
    { x : Int
    , y : Int
    , result : Int
    }


{-| Our internal state.

Just tracks all incoming messages.

-}
type alias State =
    List Message


{-| A `MessageResponse` encapsulates a message.

`NoResponse` is currently unused, but many PortFunnel-aware modules will need it.

-}
type Response
    = NoResponse
    | MessageResponse Message


{-| `AddMessage` and `MultiplyMessage` go out from Elm to the JS.

`SumMessage` and `ProductMessage` come back in.

-}
type Message
    = AddMessage Question
    | MultiplyMessage Question
    | SumMessage Answer
    | ProductMessage Answer


{-| The initial, empty state, so the application can initialize its state.
-}
initialState : State
initialState =
    []


{-| The name of this module: "AddXY".
-}
moduleName : String
moduleName =
    "AddXY"


{-| Our module descriptor.
-}
moduleDesc : ModuleDesc Message State Response
moduleDesc =
    PortFunnel.makeModuleDesc moduleName encode decode process


encode : Message -> GenericMessage
encode message =
    case message of
        AddMessage { x, y } ->
            GenericMessage moduleName
                "add"
            <|
                JE.object
                    [ ( "x", JE.int x )
                    , ( "y", JE.int y )
                    ]

        SumMessage { x, y, result } ->
            GenericMessage moduleName
                "sum"
            <|
                JE.object
                    [ ( "x", JE.int x )
                    , ( "y", JE.int y )
                    , ( "result", JE.int result )
                    ]

        MultiplyMessage { x, y } ->
            GenericMessage moduleName
                "multiply"
            <|
                JE.object
                    [ ( "x", JE.int x )
                    , ( "y", JE.int y )
                    ]

        ProductMessage { x, y, result } ->
            GenericMessage moduleName
                "product"
            <|
                JE.object
                    [ ( "x", JE.int x )
                    , ( "y", JE.int y )
                    , ( "result", JE.int result )
                    ]


addDecoder : (Question -> Message) -> Decoder Message
addDecoder tagger =
    JD.map2 (\x y -> tagger { x = x, y = y })
        (JD.field "x" JD.int)
        (JD.field "y" JD.int)


resultDecoder : (Answer -> Message) -> Decoder Message
resultDecoder tagger =
    JD.map3 (\x y result -> tagger { x = x, y = y, result = result })
        (JD.field "x" JD.int)
        (JD.field "y" JD.int)
        (JD.field "result" JD.int)


decodeValue : Decoder x -> Value -> Result String x
decodeValue decoder value =
    case JD.decodeValue decoder value of
        Ok x ->
            Ok x

        Err err ->
            Err <| JD.errorToString err


decode : GenericMessage -> Result String Message
decode { tag, args } =
    case tag of
        "add" ->
            decodeValue (addDecoder AddMessage) args

        "multiply" ->
            decodeValue (addDecoder MultiplyMessage) args

        "sum" ->
            decodeValue (resultDecoder SumMessage) args

        "product" ->
            decodeValue (resultDecoder ProductMessage) args

        _ ->
            Err <| "Unknown AddXY tag: " ++ tag


{-| Send a `Message` through a `Cmd` port.
-}
send : (Value -> Cmd msg) -> Message -> Cmd msg
send tagger message =
    PortFunnel.sendMessage moduleDesc tagger <|
        message


process : Message -> State -> ( State, Response )
process message state =
    case message of
        SumMessage _ ->
            ( message :: state, MessageResponse message )

        ProductMessage _ ->
            ( message :: state, MessageResponse message )

        _ ->
            ( state, NoResponse )


{-| Responsible for sending a `CmdResponse` back througt the port.

Called by `PortFunnel.appProcess` for each response returned by `process`.

The `AddXY` module doesn't send itself messages, so this is just `PortFunnel.emptyCommander`.

-}
commander : (GenericMessage -> Cmd msg) -> Response -> Cmd msg
commander =
    PortFunnel.emptyCommander


simulator : Message -> Maybe Message
simulator message =
    case message of
        AddMessage { x, y } ->
            Just <| SumMessage (Answer x y (x + y))

        MultiplyMessage { x, y } ->
            Just <| ProductMessage (Answer x y (x * y))

        _ ->
            Nothing


{-| Make a simulated `Cmd` port.
-}
makeSimulatedCmdPort : (Value -> msg) -> Value -> Cmd msg
makeSimulatedCmdPort =
    PortFunnel.makeSimulatedFunnelCmdPort
        moduleDesc
        simulator


{-| Convert a `Message` to a nice-looking human-readable string.
-}
toString : Message -> String
toString message =
    case message of
        AddMessage { x, y } ->
            String.fromInt x
                ++ " + "
                ++ String.fromInt y

        SumMessage { x, y, result } ->
            String.fromInt x
                ++ " + "
                ++ String.fromInt y
                ++ " = "
                ++ String.fromInt result

        MultiplyMessage { x, y } ->
            String.fromInt x
                ++ " + "
                ++ String.fromInt y

        ProductMessage { x, y, result } ->
            String.fromInt x
                ++ " * "
                ++ String.fromInt y
                ++ " = "
                ++ String.fromInt result


{-| Convert a `Message` to the same JSON string that gets sent

over the wire to the JS code.

-}
toJsonString : Message -> String
toJsonString message =
    encode message
        |> PortFunnel.encodeGenericMessage
        |> JE.encode 0


{-| Make an `AddMessage`
-}
makeAddMessage : Int -> Int -> Message
makeAddMessage x y =
    AddMessage { x = x, y = y }


{-| Make a `MultiplyMessage`
-}
makeMultiplyMessage : Int -> Int -> Message
makeMultiplyMessage x y =
    MultiplyMessage { x = x, y = y }


{-| Convert our `State` to a list of strings.
-}
stateToStrings : State -> List String
stateToStrings state =
    List.map toJsonString state
