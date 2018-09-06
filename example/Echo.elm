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


module Echo exposing (Message, Response(..), State, initialState, moduleDesc)

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


moduleDesc : ModuleDesc Message State Response
moduleDesc =
    PortFunnel.makeModuleDesc moduleName encode decode process


encode : Message -> GenericMessage
encode message =
    GenericMessage moduleName "request" <| JE.string message


decode : GenericMessage -> Result String Message
decode { tag, args } =
    case tag of
        "request" ->
            case JD.decodeValue JD.string args of
                Ok string ->
                    Ok string

                Err _ ->
                    Err <|
                        "Echo args not a string: "
                            ++ JE.encode 0 args

        _ ->
            Err <| "Unknown Echo tag: " ++ tag


process : Message -> State -> ( State, Response )
process message state =
    ( message :: state
    , MessageResponse message
    )
