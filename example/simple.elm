----------------------------------------------------------------------
--
-- simple.elm
-- Boilerplate for a port-only PortFunnel-using application.
-- This is boilerplate.elm with the simulation support removed.
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE.txt
--
----------------------------------------------------------------------


port module Main exposing (main)

{-| This is a bare-bones PortFunnel application.

It will display an interface in `elm reactor`, but won't do anything.

To get it to work, you need to compile it into `site/elm.js` (with,
e.g., the `bin/build-simple` script, and then aim your browser at
`site/index.html`.

-}

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, div, h1, input, p, span, text)
import Html.Attributes exposing (checked, style, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Json.Encode as JE exposing (Value)
import PortFunnel
    exposing
        ( FunnelSpec
        , GenericMessage
        , ModuleDesc
        , StateAccessors
        )
import PortFunnel.Echo as Echo


{-| Here's where you define your ports.

You can name them something besides `cmdPort` and `subPort`,
but then you have to change the call to `PortFunnel.subscribe()`
in `site/index.html`. Why bother?

If you run the application in `elm reactor`, these will go nowhere.

-}
port cmdPort : Value -> Cmd msg


port subPort : (Value -> msg) -> Sub msg


{-| You may have other subscriptions, but you need at least this one,
or nothing sent back from the port JavaScript will get to your code.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    subPort Process


{-| You need to store the state of each module you use.
-}
type alias State =
    { echo : Echo.State
    }


{-| And you need to initialize that state.

Some modules have parmeters to their `initialState` functions.

In that case, you may have to delay this packaging until you know the
values for those parameters.

-}
initialState : State
initialState =
    { echo = Echo.initialState
    }


{-| `StateAccessors`, `FunnelSpec`, `ModuleDesc`, `commander`, and handlers

are all packaged up for each port module, and indexed so they can
be easily looked up by `moduleName` when messages come in from the
subscription port.

The `ModuleDesc` and `commander` are usually exposed by each port module. The others are defined by your application.

Here are the `StateAccessors` for the `Echo` module.

-}
echoAccessors : StateAccessors State Echo.State
echoAccessors =
    StateAccessors .echo (\substate state -> { state | echo = substate })


{-| An `AppFunnel` is a `FunnelSpec` with the `state`, `model`, and `msg` made concrete.
-}
type alias AppFunnel substate message response =
    FunnelSpec State substate message response Model Msg


{-| A `Funnel` tags a module-specific `FunnelSpec`,

with all the variable types made concrete.

-}
type Funnel
    = EchoFunnel (AppFunnel Echo.State Echo.Message Echo.Response)


{-| Finally, a `Dict` mapping `moduleName` to tagged concrete `FunnelSpec`.
-}
funnels : Dict String Funnel
funnels =
    Dict.fromList
        [ ( Echo.moduleName
          , EchoFunnel <|
                FunnelSpec echoAccessors
                    Echo.moduleDesc
                    Echo.commander
                    echoHandler
          )
        ]


{-| After the `Echo` module processes a `GenericMessage` into an `Echo.Response`,

this function is called to do something with that response.

You'll need a separate handler function for each port module.

-}
echoHandler : Echo.Response -> State -> Model -> ( Model, Cmd Msg )
echoHandler response state model =
    ( { model
        | state = state
        , echoed =
            case response of
                Echo.MessageResponse message ->
                    Echo.toString message :: model.echoed

                Echo.ListResponse responses ->
                    List.concat
                        [ Echo.findMessages responses
                            |> List.map Echo.toString
                        , model.echoed
                        ]

                _ ->
                    model.echoed
      }
    , Cmd.none
    )


{-| After parsing the `Value` that comes in to `update` with the `Process` msg,

This function passes the module-specific `cmdPort` and `FunnelSpec` (`AppFunnel`)
into `PortFunnel` for processing. Note that `substate`, `message`, and `response`
can all be type variables here, because `PortFunnel.appProcess` just
passes them through to the module-specific functions in the `AppFunnel`.

-}
process : GenericMessage -> AppFunnel substate message response -> Model -> ( Model, Cmd Msg )
process genericMessage funnel model =
    case
        PortFunnel.appProcess cmdPort
            genericMessage
            funnel
            model.state
            model
    of
        Err error ->
            ( { model | error = Just error }, Cmd.none )

        Ok ( model2, cmd ) ->
            ( model2, cmd )


{-| Here when we've parsed the incoming `GenericMessage`,

and have found the `Funnel` for the module that will process it.

-}
processFunnel : GenericMessage -> Funnel -> Model -> ( Model, Cmd Msg )
processFunnel genericMessage funnel model =
    -- Dispatch on the `Funnel` type.
    -- This example has only one possibility.
    case funnel of
        EchoFunnel appFunnel ->
            process genericMessage appFunnel model


{-| Called from `update` to process a `Value` from the `subPort`.
-}
processValue : Value -> Model -> ( Model, Cmd Msg )
processValue value model =
    -- Parse the incoming `Value` into a `GenericMessage`.
    case PortFunnel.decodeGenericMessage value of
        Err error ->
            ( { model | error = Just error }, Cmd.none )

        Ok genericMessage ->
            let
                moduleName =
                    genericMessage.moduleName
            in
            -- Dispatch on the `moduleName`
            case Dict.get moduleName funnels of
                Nothing ->
                    ( { model
                        | error =
                            Just ("Unknown moduleName: " ++ moduleName)
                      }
                    , Cmd.none
                    )

                Just funnel ->
                    processFunnel genericMessage funnel model


{-| Our model.

`state` contains the port module state.
`error` is used to report parsing and processing errors.
`echo` is the value in the text box next to the `Echo` button.
`echoed` is a list of strings that have been echoed, most recent first.

-}
type alias Model =
    { state : State
    , error : Maybe String
    , echo : String
    , echoed : List String
    }


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init () =
    ( { state = initialState
      , error = Nothing
      , echo = "foo"
      , echoed = []
      }
    , Cmd.none
    )


{-| The `Process` message handles messages coming in from the subscription port.

All the others are application specific.

-}
type Msg
    = Process Value
    | SetEcho String
    | Echo


{-| The `Process` message is the interesting one here.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg modl =
    let
        model =
            { modl | error = Nothing }
    in
    case msg of
        SetEcho echo ->
            ( { model
                | echo = echo
                , error =
                    if echo == "error" then
                        Just "You said \"error\", so I did it."

                    else
                        Nothing
              }
            , Cmd.none
            )

        Echo ->
            ( model
            , Echo.makeMessage model.echo
                |> Echo.send cmdPort
            )

        Process value ->
            processValue value model


br =
    Html.br [] []


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "PortFunnel Example" ]
        , case model.error of
            Nothing ->
                text ""

            Just err ->
                p [ style "color" "red" ]
                    [ text err ]
        , p []
            [ input
                [ value model.echo
                , onInput SetEcho
                ]
                []
            , text " "
            , button [ onClick Echo ]
                [ text "Echo" ]
            , br
            , span [] <|
                List.map (\echoed -> span [] [ br, text echoed ])
                    model.echoed
            ]
        ]
