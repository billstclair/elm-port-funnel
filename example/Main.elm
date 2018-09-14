----------------------------------------------------------------------
--
-- PortFunnel.elm
-- Sample application for the PortFunnel module.
-- Copyright (c) 2018 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE.txt
--
----------------------------------------------------------------------


port module Main exposing (main)

import Browser
import Cmd.Extra exposing (addCmd, addCmds, withCmd, withCmds, withNoCmd)
import Dict exposing (Dict)
import Element
    exposing
        ( Attribute
        , Element
        , column
        , el
        , link
        , none
        , padding
        , paddingXY
        , paragraph
        , px
        , row
        , spacing
        , text
        , width
        )
import Element.Border as Border
import Element.Font as Font exposing (bold, size)
import Element.Input as Input exposing (Label)
import Html exposing (Html)
import Json.Encode as JE exposing (Value)
import PortFunnel
    exposing
        ( FunnelSpec
        , GenericMessage
        , ModuleDesc
        , StateAccessors
        )
import PortFunnel.AddXY as AddXY
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


simulatedAddXYCmdPort : Value -> Cmd Msg
simulatedAddXYCmdPort =
    AddXY.makeSimulatedCmdPort Process


{-| You may want simulator use to be automatic.

If so, keep a `useSimulator` flag in your `Model`, and check it here.

-}
getEchoCmdPort : Model -> (Value -> Cmd Msg)
getEchoCmdPort model =
    if model.useSimulator then
        simulatedEchoCmdPort

    else
        cmdPort


getAddXYCmdPort : Model -> (Value -> Cmd Msg)
getAddXYCmdPort model =
    if model.useSimulator then
        simulatedAddXYCmdPort

    else
        cmdPort


{-| You need to store the state of each module you use.
-}
type alias State =
    { echo : Echo.State
    , addxy : AddXY.State
    }


{-| And you need to initialize that state.

Some modules have parmeters to their `initialState` functions.

In that case, you may have to delay this packaging until you know the
values for those parameters.

-}
initialState : State
initialState =
    { echo = Echo.initialState
    , addxy = AddXY.initialState
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


{-| And for the `AddXY` module.
-}
addxyAccessors : StateAccessors State AddXY.State
addxyAccessors =
    StateAccessors .addxy (\substate state -> { state | addxy = substate })


{-| An `AppFunnel` is a `FunnelSpec` with the `state`, `model`, and `msg` made concrete.
-}
type alias AppFunnel substate message response =
    FunnelSpec State substate message response Model Msg


{-| A `Funnel` tags a module-specific `FunnelSpec`,

with all the variable types made concrete.

-}
type Funnel
    = EchoFunnel (AppFunnel Echo.State Echo.Message Echo.Response)
    | AddXYFunnel (AppFunnel AddXY.State AddXY.Message AddXY.Response)


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
        , ( AddXY.moduleName
          , AddXYFunnel <|
                FunnelSpec addxyAccessors
                    AddXY.moduleDesc
                    AddXY.commander
                    addXYHandler
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
        getAddXYCmdPort model


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


{-| Here's the handler for message from the AddXY module's JavaScript.
-}
addXYHandler : AddXY.Response -> State -> Model -> ( Model, Cmd Msg )
addXYHandler response state model =
    ( { model
        | state = state
        , sums =
            case response of
                AddXY.MessageResponse message ->
                    AddXY.toString message :: model.sums

                _ ->
                    model.sums
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
        PortFunnel.appProcess (getGMCmdPort genericMessage model)
            genericMessage
            funnel
            model.state
            model
    of
        Err error ->
            { model | error = Just error } |> withNoCmd

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
            let
                wasLoaded =
                    Echo.isLoaded model.state.echo

                ( mdl, cmd ) =
                    process genericMessage appFunnel model
            in
            if
                not wasLoaded
                    && Echo.isLoaded mdl.state.echo
            then
                { mdl | useSimulator = False }
                    |> withCmds
                        [ cmd

                        -- Test that this gets queued behind
                        -- "If you see this, startup queueing is working."
                        -- sent by `init` below.
                        , Echo.makeMessage
                            "This should happen second."
                            |> Echo.send cmdPort
                        ]

            else
                mdl |> withCmd cmd

        -- Many modules send a `Startup` message to notify the Elm code.
        -- You only need to use one of those for the simulator determination.
        AddXYFunnel appFunnel ->
            process genericMessage appFunnel model


{-| Called from `update` to process a `Value` from the `subPort`.
-}
processValue : Value -> Model -> ( Model, Cmd Msg )
processValue value model =
    -- Parse the incoming `Value` into a `GenericMessage`.
    case PortFunnel.decodeGenericMessage value of
        Err error ->
            { model | error = Just error }
                |> withNoCmd

        Ok genericMessage ->
            let
                moduleName =
                    genericMessage.moduleName
            in
            case Dict.get moduleName funnels of
                Nothing ->
                    { model
                        | error =
                            Just ("Unknown moduleName: " ++ moduleName)
                    }
                        |> withNoCmd

                Just funnel ->
                    processFunnel genericMessage funnel model


{-| Our model.

`state` contains the port module state.
`error` is used to report parsing and processing errors.
`useSimulator` controls whether we use the simulator(s) or the real port.
`x` and `y` are the inputs for the `AddXY` module.
`sums` is a list of its outputs.
`echo` is the input for the `Echo` module.
`echoed` is a list of its outputs.

-}
type alias Model =
    { state : State
    , error : Maybe String
    , useSimulator : Bool
    , x : String
    , y : String
    , sums : List String
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
      , x = "2"
      , y = "3"
      , sums = []
      , echo = "foo"
      , echoed = []
      }
    , Echo.makeMessage "If you see this, startup queueing is working."
        |> Echo.send cmdPort
    )


{-| The `Process` message handles messages coming in from the subscription port.

All the others are application specific.

-}
type Msg
    = Process Value
    | SetUseSimulator Bool
    | SetX String
    | SetY String
    | Add
    | Multiply
    | SetEcho String
    | Echo


toInt : Int -> String -> Int
toInt default string =
    String.toInt string
        |> Maybe.withDefault default


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Process value ->
            processValue value model

        SetUseSimulator useSimulator ->
            { model | useSimulator = useSimulator } |> withNoCmd

        SetX x ->
            { model | x = x } |> withNoCmd

        SetY y ->
            { model | y = y } |> withNoCmd

        SetEcho echo ->
            { model | echo = echo } |> withNoCmd

        Add ->
            model
                |> withCmd
                    (AddXY.makeAddMessage (toInt 0 model.x) (toInt 0 model.y)
                        |> AddXY.send (getAddXYCmdPort model)
                    )

        Multiply ->
            model
                |> withCmd
                    (AddXY.makeMultiplyMessage (toInt 0 model.x) (toInt 0 model.y)
                        |> AddXY.send (getAddXYCmdPort model)
                    )

        Echo ->
            model
                |> withCmd
                    (Echo.makeMessage model.echo
                        |> Echo.send (getEchoCmdPort model)
                    )


{-| Below here is User Interface.

I used this as an opportunity for my first trial at `mdgriffith/elm-ui`.
It's rough, but I think I'm going to learn to like it.

-}
fontSize : Float
fontSize =
    20


scaled : Int -> Int
scaled x =
    Element.modular fontSize 1.25 x |> round


em x =
    px (round <| fontSize * x)


h1 : String -> Element msg
h1 str =
    row
        [ paddingXY 0 (scaled -1)
        , bold
        , size <| scaled 4
        ]
        [ text str ]


b : String -> Element msg
b str =
    el [ bold ] (text str)


blankLabel : Label msg
blankLabel =
    Input.labelLeft [] none


inputText : List (Attribute msg) -> { onChange : String -> msg, text : String } -> Element msg
inputText attrs r =
    Input.text (padding (scaled -5) :: attrs)
        { onChange = r.onChange
        , text = r.text
        , label = blankLabel
        , placeholder = Nothing
        }


inputButton : { onPress : Maybe msg, label : Element msg } -> Element msg
inputButton body =
    Input.button
        [ Border.solid
        , Border.rounded (scaled -2)
        , Border.width 2
        , padding (scaled -6)
        ]
        body


edges =
    { top = 0, right = 0, bottom = 0, left = 0 }


bottomPad x =
    Element.paddingEach { edges | bottom = x }


topPad x =
    Element.paddingEach { edges | top = x }


vPad =
    scaled -4


view : Model -> Html Msg
view model =
    Element.layout
        [ paddingXY (scaled -1) 0
        , size (scaled 1)
        , spacing (scaled 1)
        ]
        (column []
            [ h1 "PortFunnel Example"
            , row []
                [ Input.checkbox [ bottomPad vPad ]
                    { onChange = SetUseSimulator
                    , icon = Input.defaultCheckbox
                    , checked = model.useSimulator
                    , label = Input.labelLeft [] (text "Use Simulator: ")
                    }
                ]
            , row []
                [ column [ Element.alignTop ] <|
                    List.concat
                        [ [ row [ bottomPad vPad ]
                                [ inputText [ width (px <| scaled 5) ]
                                    { onChange = SetX
                                    , text = model.x
                                    }
                                , text " "
                                , inputText [ width (px <| scaled 5) ]
                                    { onChange = SetY
                                    , text = model.y
                                    }
                                , text " "
                                , inputButton
                                    { onPress = Just Add
                                    , label = text "Add"
                                    }
                                , text " "
                                , inputButton
                                    { onPress = Just Multiply
                                    , label = text "Multiply"
                                    }
                                ]
                          ]
                        , lines model.sums
                        , [ row [] [ text " " ]
                          , row
                                [ bottomPad vPad
                                ]
                                [ b "Messages:" ]
                          ]
                        , lines <| AddXY.stateToStrings model.state.addxy
                        ]
                , column [ width (px <| scaled 5) ] []
                , column [ Element.alignTop ] <|
                    List.concat
                        [ [ row [ bottomPad vPad ]
                                [ inputText [ width (px <| scaled 10) ]
                                    { onChange = SetEcho
                                    , text = model.echo
                                    }
                                , text " "
                                , inputButton
                                    { onPress = Just Echo
                                    , label = text "Echo"
                                    }
                                ]
                          ]
                        , lines model.echoed
                        , [ row [] [ text " " ]
                          , row
                                [ bottomPad vPad
                                ]
                                [ b "Messages:" ]
                          ]
                        , lines <| Echo.stateToStrings model.state.echo
                        ]
                ]
            , row [ bottomPad vPad ] [ text "" ]
            , row
                [ bottomPad vPad ]
                [ b "Help:" ]
            , p
                [ "If the 'Use Simulator' checkbox is checked, a local pure Elm'"
                , " simulator will be used. If it is NOT checked, then the"
                , " real ports will be used, and if they aren't hooked up"
                , " properly, nothing will happen."
                , " If 'Use Simulator' is checked at startup, then the"
                , " Echo module's JavaScript backend didn't successfully"
                , " initialize (or you're running the code from"
                , " 'example/Main.elm', in 'elm reactor', instead of from"
                , " 'example/site/index.html'."
                ]
            , p
                [ "Fill in the two numbers and click 'Add' to add them together,"
                , " or 'Multiply' to multiply them."
                , " The AddXY port code will do it a second time,"
                , " with incremented numbers, a second later."
                ]
            , p
                [ "Click 'Echo' to send the text to its left through the"
                , " Echo port. If the text begins with a dollar sign (\"$\"),"
                , " The tail, without the dollar sign, will be sent"
                , " through the port, to illustrate how to do that."
                ]
            , p
                [ "The 'Messages' sections show what is actually received"
                , " through the Sub port."
                ]
            , row [ bottomPad vPad ] [ text "" ]
            , row [ bottomPad vPad ]
                [ paragraph []
                    [ b "Package: "
                    , link [ Font.underline ]
                        { url = "https://package.elm-lang.org/packages/billstclair/elm-port-funnel/latest"
                        , label = text "billstclair/elm-port-funnel"
                        }
                    ]
                ]
            , row [ bottomPad vPad ]
                [ paragraph []
                    [ b "GitHub: "
                    , link [ Font.underline ]
                        { url = "https://github.com/billstclair/elm-port-funnel"
                        , label = text "github.com/billstclair/elm-port-funnel"
                        }
                    ]
                ]
            ]
        )


p : List String -> Element msg
p strings =
    row
        [ width <| em 40
        , bottomPad <| round (1.5 * toFloat vPad)
        ]
        [ paragraph [] <| List.map text strings ]


lines : List String -> List (Element msg)
lines strings =
    List.map
        (\line ->
            row [] [ text line ]
        )
        strings
