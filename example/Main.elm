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
import Echo
import Html exposing (Html, text)
import Json.Encode as JE exposing (Value)
import PortFunnel exposing (GenericMessage, ModuleDesc)


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


echoInjector : Echo.State -> State -> State
echoInjector substate state =
    { state | echo = substate }


addxyInjector : AddXY.State -> State -> State
addxyInjector substate state =
    { state | addxy = substate }


echoDesc : ModuleDesc Msg Echo.Message State Echo.State Echo.Response
echoDesc =
    Echo.makeModuleDesc .echo echoInjector


addxyDesc : ModuleDesc Msg AddXY.Message State AddXY.State AddXY.Response
addxyDesc =
    AddXY.makeModuleDesc .addxy addxyInjector


type Msg
    = Process Value


process : ModuleDesc Msg message State substate response -> (response -> State -> Model -> ( Model, Cmd Msg )) -> GenericMessage -> Model -> ( Model, Cmd Msg )
process moduleDesc processor genericMessage model =
    case PortFunnel.process cmdPort moduleDesc genericMessage model.state of
        Err error ->
            ( { model | error = Just error }, Cmd.none )

        Ok ( state2, response ) ->
            processor response state2 { model | error = Nothing }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Process value ->
            case PortFunnel.decodeGenericMessage value of
                Err error ->
                    ( { model | error = Just error }, Cmd.none )

                Ok genericMessage ->
                    case genericMessage.moduleName of
                        "Echo" ->
                            process echoDesc
                                processEcho
                                genericMessage
                                model

                        "AddXY" ->
                            process addxyDesc
                                processAddxy
                                genericMessage
                                model

                        name ->
                            ( { model
                                | error =
                                    Just <| "Unknown module: " ++ name
                              }
                            , Cmd.none
                            )


{-| TODO: Do something with the response here.
-}
processEcho : Echo.Response -> State -> Model -> ( Model, Cmd Msg )
processEcho response state model =
    ( { model | state = state }
    , Cmd.none
    )


{-| TODO: Do something with the response here.
-}
processAddxy : AddXY.Response -> State -> Model -> ( Model, Cmd Msg )
processAddxy response state model =
    ( { model | state = state }
    , Cmd.none
    )


view : Model -> Html Msg
view model =
    text "Hello World!"
