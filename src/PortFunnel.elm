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
    ( ModuleDesc, GenericMessage
    , makeModuleDesc, getModuleDescName
    , process, getProp
    , encodeGenericMessage, decodeGenericMessage
    , genericMessageDecoder
    )

{-| PortFunnel allows you easily use multiple port modules.

You create a single outgoing/incoming pair of ports, and PortFunnel does the rest.

Some very simple JavaScript boilerplate directs `PortFunnel.js` to load and wire up all the other PortFunnel-aware JavaScript files. You write one simple case statement to choose which port package's message is coming in, and then write package-specific code to handle each one.


## Types

@docs ModuleDesc, GenericMessage


## PortFunnel-aware Modules

@docs makeModuleDesc, getModuleDescName


## API

@docs process, getProp


## Low-level conversion between `Value` and `GenericMessage`

@docs encodeGenericMessage, decodeGenericMessage
@docs genericMessageDecoder, argsDecoder

-}

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


{-| A full description of a module to be funneled.

`moduleName` is the name that is passed through the module headed for `<moduleName>.js`.

`encoder` and `decoder` convert between module-specific messages and `GenericMessage`.

`process` does module-specific processing.

-}
type alias ModuleDescRecord msg message state substate response =
    { moduleName : String
    , encoder : message -> GenericMessage
    , decoder : GenericMessage -> Result String message
    , extractor : state -> substate
    , injector : substate -> state -> state
    , process : (message -> Cmd msg) -> message -> substate -> ( substate, response )
    }


{-| Everything we need to know to route one module's messages.
-}
type ModuleDesc msg message state substate response
    = ModuleDesc (ModuleDescRecord msg message state substate response)


{-| Make a `ModuleDesc`.

A module-specific one of these be available from a `PortFunnel`-aware module.

-}
makeModuleDesc : String -> (message -> GenericMessage) -> (GenericMessage -> Result String message) -> (state -> substate) -> (substate -> state -> state) -> ((message -> Cmd msg) -> message -> substate -> ( substate, response )) -> ModuleDesc msg message state substate response
makeModuleDesc name encoder decoder extractor injector processor =
    ModuleDesc <|
        ModuleDescRecord name encoder decoder extractor injector processor


{-| Get the name from a `ModuleDesc`.
-}
getModuleDescName : ModuleDesc msg message state substate response -> String
getModuleDescName (ModuleDesc moduleDesc) =
    moduleDesc.moduleName


{-| Process a message received from your `Sub port`

Since that port has a signature of `(Value -> msg) -> Sub msg`, you must first call `encodeGenericMessage` to turn the `Value` into a `GenericMessage`. Then you use the `moduleName` field of the `GenericMessage` to select a `ModuleDesc`.

See `Main.elm` in the `example` directory for an example of using two PortFunnel-aware modules in one application.

-}
process : (Value -> Cmd msg) -> ModuleDesc msg message state substate response -> GenericMessage -> state -> Result String ( state, response )
process cmdPort (ModuleDesc moduleDesc) genericMessage state =
    case moduleDesc.decoder genericMessage of
        Err err ->
            Err err

        Ok message ->
            let
                messagePort mess =
                    moduleDesc.encoder mess
                        |> encodeGenericMessage
                        |> cmdPort

                substate =
                    moduleDesc.extractor state

                ( substate2, response ) =
                    moduleDesc.process messagePort message substate
            in
            Ok
                ( moduleDesc.injector substate2 state
                , response
                )


{-| Look up a property in a list of `(String, property)` pairs.
-}
getProp : String -> List ( String, a ) -> Maybe a
getProp name list =
    case LE.find (\( a, _ ) -> name == a) list of
        Just ( _, a ) ->
            Just a

        Nothing ->
            Nothing



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
