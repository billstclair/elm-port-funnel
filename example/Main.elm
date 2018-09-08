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

import AddXY
import Browser
import Cmd.Extra exposing (addCmd, addCmds, withCmd, withCmds, withNoCmd)
import Dict exposing (Dict)
import Echo
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


port cmdPort : Value -> Cmd msg


port subPort : (Value -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    subPort Process


type alias State =
    { echo : Echo.State
    , addxy : AddXY.State
    }


initialState : State
initialState =
    { echo = Echo.initialState
    , addxy = AddXY.initialState
    }


type alias Model =
    { state : State
    , error : Maybe String
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
      , x = "2"
      , y = "3"
      , sums = []
      , echo = "foo"
      , echoed = []
      }
    , Cmd.none
    )


echoAccessors : StateAccessors State Echo.State
echoAccessors =
    StateAccessors .echo (\substate state -> { state | echo = substate })


addxyAccessors : StateAccessors State AddXY.State
addxyAccessors =
    StateAccessors .addxy (\substate state -> { state | addxy = substate })


type alias AppFunnel substate message response =
    FunnelSpec State substate message response Model Msg


type Funnel
    = EchoFunnel (AppFunnel Echo.State Echo.Message Echo.Response)
    | AddXYFunnel (AppFunnel AddXY.State AddXY.Message AddXY.Response)


emptyCommander : (GenericMessage -> Cmd msg) -> response -> Cmd msg
emptyCommander _ _ =
    Cmd.none


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
                    emptyCommander
                    addXYHandler
          )
        ]


type Msg
    = Process Value
    | SetX String
    | SetY String
    | Sum
    | Multiply
    | SetEcho String
    | Echo


process : GenericMessage -> AppFunnel substate message response -> Model -> ( Model, Cmd Msg )
process genericMessage funnel model =
    case PortFunnel.appProcess cmdPort genericMessage funnel model.state model of
        Err error ->
            { model | error = Just error } |> withNoCmd

        Ok ( model2, cmd ) ->
            ( model2, cmd )


toInt : Int -> String -> Int
toInt default string =
    String.toInt string
        |> Maybe.withDefault default


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetX x ->
            { model | x = x } |> withNoCmd

        SetY y ->
            { model | y = y } |> withNoCmd

        SetEcho echo ->
            { model | echo = echo } |> withNoCmd

        Sum ->
            model
                |> withCmd
                    (AddXY.makeAddMessage (toInt 0 model.x) (toInt 0 model.y)
                        |> AddXY.send cmdPort
                    )

        Multiply ->
            model
                |> withCmd
                    (AddXY.makeMultiplyMessage (toInt 0 model.x) (toInt 0 model.y)
                        |> AddXY.send cmdPort
                    )

        Echo ->
            model |> withCmd (Echo.send cmdPort model.echo)

        Process value ->
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
                            case funnel of
                                EchoFunnel appFunnel ->
                                    process genericMessage appFunnel model

                                AddXYFunnel appFunnel ->
                                    process genericMessage appFunnel model


findEchoMessages : List Echo.Response -> List Echo.Message
findEchoMessages responses =
    List.foldr
        (\response res ->
            case response of
                Echo.MessageResponse message ->
                    message :: res

                Echo.ListResponse resps ->
                    List.append
                        (findEchoMessages resps)
                        res

                _ ->
                    res
        )
        []
        responses


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
                                    { onPress = Just Sum
                                    , label = text "Sum"
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
                [ "Fill in the two numbers and click 'Sum' to add them together,"
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
