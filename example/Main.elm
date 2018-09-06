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
import Html exposing (Html, text)
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


view : Model -> Html Msg
view model =
    text "Hello World!"
