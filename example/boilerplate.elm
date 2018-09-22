----------------------------------------------------------------------
--
-- boilerplate.elm
-- Boilerplate that you'll need to use any PortFunnel funnel module.
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE.txt
--
----------------------------------------------------------------------


port module Main exposing (main)

{-| This is an example PortFunnel application file.

It will run, in `elm reactor`, or from `site/index.html`, when compiled
into `site/elm.js` (with, e.g., the `bin/build-boilerplate` script).

-}

import Browser
import Dict exposing (Dict)
import Html exposing (Html, a, button, div, h1, input, p, span, text)
import Html.Attributes exposing (checked, href, style, type_, value)
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


{-| Support for simulators.

You'll need something like this for each module you want to be able to simulate.

Totally optional, but I find it nice to be able to simulator in `elm reactor`.

-}
simulatedEchoCmdPort : Value -> Cmd Msg
simulatedEchoCmdPort =
    Echo.makeSimulatedCmdPort Process


{-| You may want simulator use to be automatic.

If so, keep a `useSimulator` flag in your `Model`, and check it here.

-}
getEchoCmdPort : Model -> (Value -> Cmd Msg)
getEchoCmdPort model =
    if model.useSimulator then
        simulatedEchoCmdPort

    else
        cmdPort


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
          , FunnelSpec echoAccessors Echo.moduleDesc Echo.commander echoHandler
                |> EchoFunnel
          )
        ]


{-| Turn the `moduleName` inside a `GenericMessage` into the port

to which to send its messages. This only needs to be here if you're
doing simulation. Otherwise, just use the real `cmdPort`.

-}
getGMCmdPort : GenericMessage -> Model -> (Value -> Cmd Msg)
getGMCmdPort genericMessage model =
    let
        moduleName =
            genericMessage.moduleName
    in
    if moduleName == Echo.moduleName then
        getEchoCmdPort model

    else
        cmdPort


{-| Some funnel modules let you know when their JavaScript has been loaded.

Here's one way to store that in the model, so we can use it to decide whether to use the simulators or the real port.

-}
doIsLoaded : Model -> Model
doIsLoaded model =
    if not model.wasLoaded && Echo.isLoaded model.state.echo then
        { model
            | useSimulator = False
            , wasLoaded = True
        }

    else
        model


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
        |> doIsLoaded
    , Cmd.none
    )


{-| This is called from `AppFunnel.processValue`.

It unboxes the `Funnel` arg, and calls `PortFunnel.appProcess`.

-}
appTrampoline : GenericMessage -> Funnel -> State -> Model -> Result String ( Model, Cmd Msg )
appTrampoline genericMessage funnel state model =
    -- Dispatch on the `Funnel` tag.
    -- This example has only one possibility.
    case funnel of
        EchoFunnel appFunnel ->
            PortFunnel.appProcess cmdPort genericMessage appFunnel state model


{-| Our model.

`state` contains the port module state.
`error` is used to report parsing and processing errors.
`useSimulator` controls whether we use the simulator(s) or the real port.
`echo` is the value in the text box next to the `Echo` button.
`echoed` is a list of strings that have been echoed, most recent first.

-}
type alias Model =
    { state : State
    , error : Maybe String
    , useSimulator : Bool
    , wasLoaded : Bool
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
      , useSimulator = True
      , wasLoaded = False
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
    | SetUseSimulator Bool
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
        Process value ->
            case
                PortFunnel.processValue funnels appTrampoline value model.state model
            of
                Err error ->
                    ( { model | error = Just error }
                    , Cmd.none
                    )

                Ok res ->
                    res

        SetUseSimulator useSimulator ->
            ( { model | useSimulator = useSimulator }, Cmd.none )

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
                |> Echo.send (getEchoCmdPort model)
            )


{-| Finally, make it all visible in the browser.
-}
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
            [ text "Use simulator: "
            , input
                [ type_ "checkbox"
                , onCheck SetUseSimulator
                , checked model.useSimulator
                ]
                []
            , br
            , input
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
        , p []
            [ text "Source code: "
            , a [ href "https://github.com/billstclair/elm-port-funnel/blob/master/example/boilerplate.elm" ]
                [ text "boilerplate.elm" ]
            ]
        ]
