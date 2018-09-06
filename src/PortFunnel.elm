module PortFunnel exposing
    ( Config, ModuleDesc, GenericMessage
    , makeConfig, makeSimulatorConfig
    , makeModuleDesc, getModuleDescName
    , makeState, process
    , encodeGenericMessage, decodeGenericMessage
    , genericMessageDecoder, argsDecoder
    )

{-| PortFunnel allows you easily use multiple port modules.

You create a single outgoing/incoming pair of ports, and PortFunnel does the rest.

Some very simple JavaScript boilerplate directs `PortFunnel.js` to load and wire up all the other PortFunnel-aware JavaScript files. You write one simple case statement to choose which port package's message is coming in, and then write package-specific code to handle each one.


## Types

@docs Config, ModuleDesc, GenericMessage


## Configuration

@docs makeConfig, makeSimulatorConfig
@docs makeModuleDesc, getModuleDescName


## API

@docs makeState, process


## Low-level conversion between `Value` and `GenericMessage`

@docs encodeGenericMessage, decodeGenericMessage
@docs genericMessageDecoder, argsDecoder

-}

import Dict exposing (Dict)
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)


{-| A generic message that goes over the wire to/from the module JavaScript.
-}
type alias GenericMessage =
    { moduleName : String
    , tag : String
    , args : List ( String, Value )
    }


{-| A full description of a module to be funneled.

`moduleName` is the name that is passed through the module headed for `<moduleName>.js`.

`encoder` and `decoder` convert between module-specific messages and `GenericMessage`.

`process` does module-specific processing.

-}
type alias ModuleDescRecord msg message state result =
    { moduleName : String
    , encoder : message -> GenericMessage
    , decoder : GenericMessage -> Result String message
    , process : (message -> Cmd msg) -> message -> state -> ( state, result )
    }


{-| Everything we need to know to route one module's messages.
-}
type ModuleDesc msg message state result
    = ModuleDesc (ModuleDescRecord msg message state result)


{-| Make a `ModuleDesc`.

A module-specific one of these be available from a `PortFunnel`-aware module.

-}
makeModuleDesc : String -> (message -> GenericMessage) -> (GenericMessage -> Result String message) -> ((message -> Cmd msg) -> message -> state -> ( state, result )) -> ModuleDesc msg message state result
makeModuleDesc name encoder decoder processor =
    ModuleDesc <|
        ModuleDescRecord name encoder decoder processor


{-| Get the name from a `ModuleDesc`.
-}
getModuleDescName : ModuleDesc msg message state result -> String
getModuleDescName (ModuleDesc moduleDesc) =
    moduleDesc.moduleName


{-| Package up your outgoing port or a simluator.
-}
type Config msg
    = Config
        { cmdPort : Value -> Cmd msg
        , simulator : Maybe (GenericMessage -> Maybe GenericMessage)
        }


{-| Make a `Config` for a real outgoing port
-}
makeConfig : (Value -> Cmd msg) -> Config msg
makeConfig cmdPort =
    Config
        { cmdPort = cmdPort
        , simulator = Nothing
        }


{-| Make a `Config` that enables running your code in `elm reactor`.

The arg is a port simulator, which translates a message sent to an optional response.

-}
makeSimulatorConfig : (GenericMessage -> Maybe GenericMessage) -> Config msg
makeSimulatorConfig simulator =
    Config
        { cmdPort = \_ -> Cmd.none
        , simulator = Just simulator
        }



--
-- State for your `Model` and processing input from the `Sub` port.
--


type alias StateRecord msg message state result =
    { config : Config msg
    , moduleDesc : ModuleDesc msg message state result
    , state : state
    }


{-| Encapsulate configuration, module description, and module state.

This is what you store in your Model, and update after calling `process`.

-}
type State msg message state result
    = State (StateRecord msg message state result)


{-| Make a `State`.
-}
makeState : Config msg -> ModuleDesc msg message state result -> state -> State msg message state result
makeState config moduleDesc state =
    State <| StateRecord config moduleDesc state


{-| Process a messsage.
-}
process : message -> State msg message state result -> ( State msg message state result, result )
process message (State state) =
    let
        (Config config) =
            state.config

        (ModuleDesc moduleDesc) =
            state.moduleDesc

        messagePort mess =
            moduleDesc.encoder mess
                |> encodeGenericMessage
                |> config.cmdPort

        ( moduleState, result ) =
            moduleDesc.process messagePort message state.state
    in
    ( State { state | state = moduleState }
    , result
    )



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
        , ( "args", JE.object message.args )
        ]


{-| Decoder for a `GenericMessage`.
-}
genericMessageDecoder : Decoder GenericMessage
genericMessageDecoder =
    JD.map3 GenericMessage
        (JD.field "module" JD.string)
        (JD.field "tag" JD.string)
        (JD.field "args" argsDecoder)


{-| Decoder for the `args` in a `GenericMessage`
-}
argsDecoder : Decoder (List ( String, Value ))
argsDecoder =
    JD.keyValuePairs JD.value


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
