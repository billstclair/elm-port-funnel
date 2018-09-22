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
    , makeModuleDesc, getModuleDescName, emptyCommander
    , send, sendMessage, processValue, appProcess, process
    , encodeGenericMessage, decodeGenericMessage
    , genericMessageDecoder
    , messageToValue, messageToJsonString
    , makeSimulatedFunnelCmdPort
    )

{-| PortFunnel allows you easily use multiple port modules.

You create a single outgoing/incoming pair of ports, and PortFunnel does the rest.

Some very simple JavaScript boilerplate directs `PortFunnel.js` to load and wire up all the other PortFunnel-aware JavaScript files. You write one simple case statement to choose which port package's message is coming in, and then write package-specific code to handle each one.


## Types

@docs FunnelSpec, ModuleDesc, StateAccessors, GenericMessage


## PortFunnel-aware Modules

@docs makeModuleDesc, getModuleDescName, emptyCommander


## API

@docs send, sendMessage, processValue, appProcess, process


## Low-level conversion between `Value` and `GenericMessage`

@docs encodeGenericMessage, decodeGenericMessage
@docs genericMessageDecoder
@docs messageToValue, messageToJsonString


## Simulated Message Processing

@docs makeSimulatedFunnelCmdPort

-}

import Cmd.Extra exposing (addCmd, addCmds, withCmd, withCmds, withNoCmd)
import Dict exposing (Dict)
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)
import List.Extra as LE
import Task


{-| A generic message that goes over the wire to/from the module JavaScript.
-}
type alias GenericMessage =
    { moduleName : String
    , tag : String
    , args : Value
    }


{-| Package up an application's functions for accessing one funnel module's state.
-}
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

A module-specific one of these is available from a `PortFunnel`-aware module. The args are:

    name encoder decoder processor

`name` is the name of the module, it must match the name of the JS file.

`encoder` turns your custom `Message` type into a `GenericMessage`.

`decoder` turns a `GenericMessage` into your custom message type.

`processor` is called when a message comes in over the subscription port. It's very similar to a standard application `update` function. `substate` is your module's `State` type, not to be confused with `state`, which is the user's application state type.

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


{-| A `commander` for a `FunnelSpec` that always returns `Cmd.none`

Useful for funnels that do not send themselves messages.

-}
emptyCommander : (GenericMessage -> Cmd msg) -> response -> Cmd msg
emptyCommander _ _ =
    Cmd.none


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
    , commander : (GenericMessage -> Cmd msg) -> response -> Cmd msg
    , handler : response -> state -> model -> ( model, Cmd msg )
    }


{-| Send a `GenericMessage` over a `Cmd port`.
-}
send : (Value -> Cmd msg) -> GenericMessage -> Cmd msg
send cmdPort message =
    encodeGenericMessage message
        |> cmdPort


{-| Send a `message` over a `Cmd port`.
-}
sendMessage : ModuleDesc message substate response -> (Value -> Cmd msg) -> message -> Cmd msg
sendMessage moduleDesc cmdPort message =
    messageToValue moduleDesc message
        |> cmdPort


{-| Process a GenericMessage.

This is low-level processing. Most applications will call this through `appProcess` via `processValue`.

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


{-| Process a `Value` from your subscription port.

    processValue funnels appTrampoline value state model

Parse the `Value` into a `GenericMessage`.

If successful, use the `moduleName` from there to look up a funnel from the `Dict` you provide.

If the lookup succeeds, call your `appTrampoline`, to unbox the `funnel` and call `PortFunnel.appProcess` to do the rest of the processing.

See `example/boilerplate.elm` and `example/simple.elm` for examples of using this.

-}
processValue : Dict String funnel -> (GenericMessage -> funnel -> state -> model -> Result String ( model, Cmd msg )) -> Value -> state -> model -> Result String ( model, Cmd msg )
processValue funnels appTrampoline value state model =
    case decodeGenericMessage value of
        Err error ->
            Err error

        Ok genericMessage ->
            let
                moduleName =
                    genericMessage.moduleName
            in
            case Dict.get moduleName funnels of
                Just funnel ->
                    case
                        appTrampoline genericMessage funnel state model
                    of
                        Err error ->
                            Err error

                        Ok ( model2, cmd ) ->
                            Ok ( model2, cmd )

                _ ->
                    Err <| "Unknown moduleName: " ++ moduleName


{-| Finish the processing begun in `processValue`.
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
                gmToCmdPort gm =
                    encodeGenericMessage gm |> cmdPort

                cmd =
                    funnel.commander gmToCmdPort response

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


{-| Convert a message to a JSON `Value`
-}
messageToValue : ModuleDesc message substate response -> message -> Value
messageToValue (ModuleDesc moduleDesc) message =
    moduleDesc.encoder message
        |> encodeGenericMessage


{-| Convert a message to a JSON `Value` and encode it as a string.
-}
messageToJsonString : ModuleDesc message substate response -> message -> String
messageToJsonString moduleDesc message =
    messageToValue moduleDesc message
        |> JE.encode 0



--
-- Support for simulated ports
--


{-| Simulate a `Cmd` port, outgoing to a funnel's backend.

    makeSimulatedFunnelCmdPort moduleDesc simulator tagger value

Usually, a funnel `Module` will provide one of these by leaving off the last two args, `tagger` and `value`:

    simulator : Message -> Maybe Message
    simulator message =
        ...

    makeSimulatedCmdPort : (Value -> msg) -> Value -> Cmd msg
    makeSimulatedCmdPort =
        PortFunnel.makeSimulatedFunnelCmdPort
            moduleDesc
            simulator

Then the application code will call `simulatedPort` with a tagger, which turns a `Value` into the application `msg` type. That gives something with the same signature, `Value -> Cmd msg` as a `Cmd` port:

    type Msg
        = Receive Value
        | ...

    simulatedModuleCmdPort : Value -> Cmd msg
    simulatedModuleCmdPort =
        Module.makeSimulatedPort Receive

This can only simulate synchronous message responses, but that's sufficient to test a lot. And it works in `elm reactor`, with no port JavaScript code.

Note that this ignores errors in decoding a `Value` to a `GenericMessage` and from there to a `message`, returning `Cmd.none` if it gets an error from either. Funnel developers will have to test their encoders and decoders separately.

-}
makeSimulatedFunnelCmdPort : ModuleDesc message substate response -> (message -> Maybe message) -> (Value -> msg) -> (Value -> Cmd msg)
makeSimulatedFunnelCmdPort (ModuleDesc moduleDesc) simulator tagger value =
    case decodeGenericMessage value of
        Err _ ->
            Cmd.none

        Ok genericMessage ->
            case moduleDesc.decoder genericMessage of
                Err _ ->
                    Cmd.none

                Ok message ->
                    case simulator message of
                        Nothing ->
                            Cmd.none

                        Just receivedMessage ->
                            moduleDesc.encoder receivedMessage
                                |> encodeGenericMessage
                                |> Task.succeed
                                |> Task.perform tagger



--
-- The "PortFunnel" funnel.
--
-- TODO
--
-- This may eventually be a nice addition, but I don't think
-- it adds enough be worth doing as yet.
--
-- Logging is probably the first thing I'll add, whenever
-- I find I need it to debug a funnel in development.
--


type LoggingWhen
    = NoLogging
    | AllLogging
    | TagsLogging (List String)


type alias EnableLoggingMessageRecord =
    { forModule : String
    , when : LoggingWhen
    }


type alias ApiElement =
    { moduleName : String
    , tag : String
    , args : String
    }


type alias Api =
    List ApiElement


type Message
    = NoMessage
    | EnableLoggingMessage EnableLoggingMessageRecord
    | QueryLoggingMessage
    | ReportLoggingMessage (List EnableLoggingMessageRecord)
    | RequestApiMessage String
    | ReportApiMessage
        { forModule : String
        , api : Api
        }
    | InstallModuleMesage String
    | ReportInstallModuleMessage
        { forModule : String
        , success : Bool
        }
    | RemoveModuleMessage String
    | ReportRemoveModuleMessage
        { forModule : String
        , success : Bool
        }
