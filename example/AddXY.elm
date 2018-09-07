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


module AddXY exposing
    ( Message(..)
    , Response(..)
    , State
    , initialState
    , moduleDesc
    , moduleName
    , toJsonString
    , toString
    )

import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (GenericMessage, ModuleDesc)


type alias Sum =
    { x : Int
    , y : Int
    , sum : Int
    }


type alias State =
    List Message


type Response
    = NoResponse
    | MessageResponse Message


type Message
    = AddMessage { x : Int, y : Int }
    | SumMessage Sum


initialState : State
initialState =
    []


{-| The name of this module: "AddXY".
-}
moduleName : String
moduleName =
    "AddXY"


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

        SumMessage { x, y, sum } ->
            GenericMessage moduleName
                "sum"
            <|
                JE.object
                    [ ( "x", JE.int x )
                    , ( "y", JE.int y )
                    , ( "sum", JE.int sum )
                    ]


addDecoder : Decoder Message
addDecoder =
    JD.map2 (\x y -> AddMessage { x = x, y = y })
        (JD.field "x" JD.int)
        (JD.field "y" JD.int)


sumDecoder : Decoder Message
sumDecoder =
    JD.map3 (\x y sum -> SumMessage { x = x, y = y, sum = sum })
        (JD.field "x" JD.int)
        (JD.field "y" JD.int)
        (JD.field "sum" JD.int)


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
            decodeValue addDecoder args

        "sum" ->
            decodeValue sumDecoder args

        _ ->
            Err <| "Unknown Echo tag: " ++ tag


send : (Value -> Cmd msg) -> Message -> Cmd msg
send cmdPort message =
    encode message
        |> PortFunnel.send cmdPort


process : Message -> State -> ( State, Response )
process message state =
    case message of
        SumMessage sum ->
            ( message :: state, MessageResponse message )

        _ ->
            ( state, NoResponse )


toString : Message -> String
toString message =
    case message of
        AddMessage { x, y } ->
            String.fromInt x
                ++ " + "
                ++ String.fromInt y

        SumMessage { x, y, sum } ->
            String.fromInt x
                ++ " + "
                ++ String.fromInt y
                ++ " = "
                ++ String.fromInt sum


toJsonString : Message -> String
toJsonString message =
    encode message
        |> PortFunnel.encodeGenericMessage
        |> JE.encode 0


stateToStringList : State -> List String
stateToStringList state =
    List.map toJsonString state
