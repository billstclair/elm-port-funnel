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
import Debug exposing (todo)
import Dict exposing (Dict)
import Echo
import Element
    exposing
        ( Attribute
        , Element
        , column
        , el
        , none
        , padding
        , paddingXY
        , paragraph
        , px
        , row
        , spacing
        , text
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
    , sum : String
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
      , sum = ""
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


{-| TODO: add commanders to Echo.elm and AddXY.elm, and use them.
-}
emptyCommander : (Value -> Cmd msg) -> response -> Cmd msg
emptyCommander _ _ =
    Cmd.none


funnels : Dict String Funnel
funnels =
    Dict.fromList
        [ ( Echo.moduleName
          , EchoFunnel <|
                FunnelSpec echoAccessors
                    Echo.moduleDesc
                    emptyCommander
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


process : GenericMessage -> AppFunnel substate message response -> Model -> ( Model, Cmd Msg )
process genericMessage funnel model =
    case PortFunnel.appProcess cmdPort genericMessage funnel model.state model of
        Err error ->
            { model | error = Just error } |> withNoCmd

        Ok ( model2, cmd ) ->
            ( model2, cmd )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetX x ->
            { model | x = x } |> withNoCmd

        SetY y ->
            { model | y = y } |> withNoCmd

        Sum ->
            { model
                | sum =
                    model.x
                        ++ " + "
                        ++ model.y
                        ++ " = "
                        ++ model.x
                        ++ model.y
            }
                |> withNoCmd

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


{-| TODO: Do something with the response here.
-}
echoHandler : Echo.Response -> State -> Model -> ( Model, Cmd Msg )
echoHandler response state model =
    ( { model | state = state }
    , Cmd.none
    )


{-| TODO: Do something with the response here.
-}
addXYHandler : AddXY.Response -> State -> Model -> ( Model, Cmd Msg )
addXYHandler response state model =
    ( { model | state = state }
    , Cmd.none
    )


scaled : Int -> Int
scaled x =
    Element.modular 16 1.25 x |> round


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
                [ inputText [ Element.width (px <| scaled 5) ]
                    { onChange = SetX
                    , text = model.x
                    }
                , text " x "
                , inputText [ Element.width (px <| scaled 5) ]
                    { onChange = SetY
                    , text = model.y
                    }
                , text " "
                , inputButton
                    { onPress = Just Sum
                    , label = text "Sum"
                    }
                ]
            , row [ paddingXY 0 (scaled -2) ]
                [ text model.sum ]
            ]
        )
