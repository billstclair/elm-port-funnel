----------------------------------------------------------------------
--
-- PortFunnel.elm
-- A mechanism for sharing a single port pair amongst many backends.
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE.txt
--
----------------------------------------------------------------------


module PortFunnel exposing
    ( FunnelSpec, ModuleDesc, StateAccessors, GenericMessage
    , makeModuleDesc, getModuleDescName
    , appProcess, process
    , encodeGenericMessage, decodeGenericMessage
    , genericMessageDecoder
    )

{-| PortFunnel allows you easily use multiple port modules.

You create a single outgoing/incoming pair of ports, and PortFunnel does the rest.

Some very simple JavaScript boilerplate directs `PortFunnel.js` to load and wire up all the other PortFunnel-aware JavaScript files. You write one simple case statement to choose which port package's message is coming in, and then write package-specific code to handle each one.


## Types

@docs FunnelSpec, ModuleDesc, StateAccessors, GenericMessage


## PortFunnel-aware Modules

@docs makeModuleDesc, getModuleDescName


## API

@docs appProcess, process


## Low-level conversion between `Value` and `GenericMessage`

@docs encodeGenericMessage, decodeGenericMessage
@docs genericMessageDecoder, argsDecoder

-}

import Cmd.Extra exposing (addCmd, addCmds, withCmd, withCmds, withNoCmd)
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import List.Extra as LE


{-| A generic message that goes over the wire to/from the module JavaScript.
-}
type alias GenericMessage =
    { moduleName : String
    , tag : String
    , args : Value
    }


type alias StateAccessors state substate =
    { get : state -> substate
    , set : substate -> state -> state
    }


{-| A full description of a module to be funneled.

`moduleName` is the name that is passed through the module headed for `<moduleName>.js`.

`encoder` and `decoder` convert between module-specific messages and `GenericMessage`.

`process` does module-specific processing.

-}
type alias ModuleDescRecord message substate response =
    { moduleName : String
    , encoder : message -> GenericMessage
    , decoder : GenericMessage -> Result String message
    , process : message -> substate -> ( substate, response )
    }


{-| Everything we need to know to route one module's messages.
-}
type ModuleDesc message substate response
    = ModuleDesc (ModuleDescRecord message substate response)


{-| Make a `ModuleDesc`.

A module-specific one of these be available from a `PortFunnel`-aware module.

-}
makeModuleDesc : String -> (message -> GenericMessage) -> (GenericMessage -> Result String message) -> (message -> substate -> ( substate, response )) -> ModuleDesc message substate response
makeModuleDesc name encoder decoder processor =
    ModuleDesc <|
        ModuleDescRecord name encoder decoder processor


{-| Get the name from a `ModuleDesc`.
-}
getModuleDescName : ModuleDesc message substate response -> String
getModuleDescName (ModuleDesc moduleDesc) =
    moduleDesc.moduleName


{-| All the information needed to use a PortFunnel-aware application

with a single PortFunnel-aware module.

`StateAccessors` is provided by the application.

`ModuleDesc` is provided by the module, usually via a `moduleDesc` variable.

`commander` is provided by the module, usually via a `commander` variable.

`handler` is provided by the application.

-}
type alias FunnelSpec state substate message response model msg =
    { accessors : StateAccessors state substate
    , moduleDesc : ModuleDesc message substate response
    , commander : (Value -> Cmd msg) -> response -> Cmd msg
    , handler : response -> state -> model -> ( model, Cmd msg )
    }


{-| Process a message received from your `Sub port`

This is low-level processing. Most applications will use `appProcess`.

-}
process : StateAccessors state substate -> ModuleDesc message substate response -> GenericMessage -> state -> Result String ( state, response )
process accessors (ModuleDesc moduleDesc) genericMessage state =
    case moduleDesc.decoder genericMessage of
        Err err ->
            Err err

        Ok message ->
            let
                substate =
                    accessors.get state

                ( substate2, response ) =
                    moduleDesc.process message substate
            in
            Ok
                ( accessors.set substate2 state
                , response
                )


{-| Once your application has a fully-realized `FunnelSpec` in its hands,

call this to do all the necessary processing.

-}
appProcess : (Value -> Cmd msg) -> GenericMessage -> FunnelSpec state substate message response model msg -> state -> model -> Result String ( model, Cmd msg )
appProcess cmdPort genericMessage funnel state model =
    case
        process funnel.accessors funnel.moduleDesc genericMessage state
    of
        Err error ->
            Err error

        Ok ( state2, response ) ->
            let
                cmd =
                    funnel.commander cmdPort response

                ( model2, cmd2 ) =
                    funnel.handler response state2 model
            in
            Ok (model2 |> withCmds [ cmd, cmd2 ])



--
-- Low-level conversion between `GenericMessage` and `Value`
--


{-| Low-level GenericMessage encoder.
-}
encodeGenericMessage : GenericMessage -> Value
encodeGenericMessage message =
    JE.object
        [ ( "module", JE.string message.moduleName )
        , ( "tag", JE.string message.tag )
        , ( "args", message.args )
        ]


{-| Decoder for a `GenericMessage`.
-}
genericMessageDecoder : Decoder GenericMessage
genericMessageDecoder =
    JD.map3 GenericMessage
        (JD.field "module" JD.string)
        (JD.field "tag" JD.string)
        (JD.field "args" JD.value)


{-| Turn a `Value` from the `Sub` port into a `GenericMessage`.
-}
decodeGenericMessage : Value -> Result String GenericMessage
decodeGenericMessage value =
    decodeValue genericMessageDecoder value


decodeValue : Decoder a -> Value -> Result String a
decodeValue decoder value =
    case JD.decodeValue decoder value of
        Ok res ->
            Ok res

        Err err ->
            Err <| JD.errorToString err
