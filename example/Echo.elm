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


module Echo exposing (Message, Response(..), State, initialState, makeModuleDesc)

import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (GenericMessage, ModuleDesc)


type alias State =
    List Message


type Response
    = NoResponse
    | MessageResponse Message
    | CmdResponse Message Message


type alias Message =
    String


initialState : State
initialState =
    []


moduleName : String
moduleName =
    "Echo"


makeModuleDesc : (state -> State) -> (State -> state -> state) -> ModuleDesc msg Message state State Response
makeModuleDesc extractor injector =
    PortFunnel.makeModuleDesc moduleName
        encode
        decode
        extractor
        injector
        process


encode : Message -> GenericMessage
encode message =
    GenericMessage moduleName "request" [ ( "string", JE.string message ) ]


decode : GenericMessage -> Result String Message
decode { tag, args } =
    case tag of
        "request" ->
            case PortFunnel.getProp "string" args of
                Nothing ->
                    Err "Missing 'string' arg."

                Just value ->
                    case JD.decodeValue JD.string value of
                        Err _ ->
                            Err <|
                                "Echo value not a string: "
                                    ++ JE.encode 0 value

                        Ok string ->
                            Ok string

        _ ->
            Err <| "Unknown Echo tag: " ++ tag


process : (Message -> Cmd msg) -> Message -> State -> ( State, Response )
process cmdPort message state =
    ( message :: state
    , MessageResponse message
    )
