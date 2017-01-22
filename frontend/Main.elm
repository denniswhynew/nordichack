import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http exposing (send, request, stringBody, expectString)
import Time

-- Speed is represented as an integer in increments of 0.2 to avoid
-- floating point fun.
speed_increment : Float
speed_increment = 0.2
min_speed_increment = 2 * 5  -- 2 Km/h
max_speed_increment = 30 * 5 -- 30 Km/h, 5 increments of 0.2


main = Html.program { init = init
                    , view = view
                    , update = update
                    , subscriptions = subscriptions }


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every (Time.second * 0.25) Tick


type alias Model =
    { speed : Int
    , requestedSpeed : Int
    , startTime : Float
    , currentTime : Float
    , distance : Float
    , error : String
    }


type Msg = IncreaseSpeed
         | DecreaseSpeed
         | SetSpeed Int
         | SetSpeedResponse (Result Http.Error String)
         | Tick Time.Time


init : (Model, Cmd Msg)
init = ({ speed = 0
        , requestedSpeed = 0
        , startTime = 0.0
        , currentTime = 0.0
        , distance = 0.0
        , error = "" }, Cmd.none)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        IncreaseSpeed -> increaseSpeed model
        DecreaseSpeed -> decreaseSpeed model
        SetSpeed speed -> changeSpeed model speed
        SetSpeedResponse result -> (updateSpeed model result, Cmd.none)
        Tick t -> (updateTimeAndDistance model t, Cmd.none)


updateTimeAndDistance : Model -> Time.Time -> Model
updateTimeAndDistance model t =
    -- This is a rough approximation because the time and speed are both inaccurate.
    -- Speed would have to come from the treadmill, as it takes several seconds for
    -- large changes in speed to occur.
    let
        timeStep =
            if model.startTime > 0 then
                Time.inHours (t - model.currentTime)
            else
                0.0
    in
    if model.speed > 0 then
        { model
            | currentTime = t
            , startTime = if model.startTime == 0 then t else model.startTime
            , distance = model.distance + (toFloat model.speed) * speed_increment * timeStep
        }
    else
        model


increaseSpeed : Model -> (Model, Cmd Msg)
increaseSpeed model =
    let
        requestedSpeed =
            if (model.speed < min_speed_increment) then
                min_speed_increment
            else
                model.speed + 1
    in
        ({ model | requestedSpeed = requestedSpeed }, postSpeedChange requestedSpeed)


decreaseSpeed : Model -> (Model, Cmd Msg)
decreaseSpeed model =
    let
        requestedSpeed =
            if (model.speed == min_speed_increment) then
                0
            else
                model.speed - 1
    in
        ({ model | requestedSpeed = requestedSpeed }, postSpeedChange requestedSpeed)


updateSpeed : Model -> Result Http.Error String -> Model
updateSpeed model result =
    let
        starting = model.speed == 0 && model.requestedSpeed /= 0
        stoping = model.speed /= 0 && model.requestedSpeed == 0

        updateModel =
            if starting then
                -- Have to check response...
                { model
                    | speed = model.requestedSpeed
                    , startTime = 0.0
                    , currentTime = 0.0
                    , distance = 0.0
                    , error = ""
                }
            else
                { model
                    | speed = model.requestedSpeed
                    , error = ""
                }
    in
    case result of
        Ok response -> updateModel
        Err error -> { model | requestedSpeed = model.speed, error = stringifyError error }


stringifyError error =
    case error of
        Http.BadUrl s -> "Bad URL: " ++ s
        Http.Timeout -> "Timeout"
        Http.NetworkError -> "Network Error"
        Http.BadStatus r -> "Bad status"
        Http.BadPayload s r -> "Bad payload"


changeSpeed : Model -> Int -> (Model, Cmd Msg)
changeSpeed model requestedSpeed =
    if requestedSpeed == 0
        || (requestedSpeed >= min_speed_increment
            && requestedSpeed <= max_speed_increment) then
        ({ model | requestedSpeed = requestedSpeed }, postSpeedChange requestedSpeed)
    else
        (model, Cmd.none)


postSpeedChange : Int -> Cmd Msg
postSpeedChange requestedSpeed =
    let
        req = Http.request { method = "POST"
                           , headers = []
                           , url = "/api/v1/desiredspeed"
                           , body = (stringBody "text/plain" (toString ((toFloat requestedSpeed) * speed_increment)))
                           , expect = expectString
                           , timeout = Just (Time.second * 2.5)
                           , withCredentials = False
                           }
    in
        Http.send (\r -> SetSpeedResponse r) req


formatTime : Time.Time -> String
formatTime t =
    let
        hours = floor(Time.inHours t)
        minutes = floor(Time.inMinutes (t - (toFloat hours) * Time.hour))
        seconds = floor(Time.inSeconds (t - (toFloat hours) * Time.hour - (toFloat minutes) * Time.minute))
    in
        (toString hours) ++ ":" ++ (toString minutes) ++ ":" ++ (toString seconds)


formatDistance : Float -> String
formatDistance d =
    let
        meters_thousands = floor(d)
        meters_hundreds = floor((d * 10 - (toFloat meters_thousands)))
        meters_tens = floor((d * 100 - (toFloat meters_hundreds)))
        meters_ones = floor((d * 1000 - (toFloat meters_tens)))
    in
        (toString meters_thousands) ++ "."
            ++ (toString meters_hundreds)
            ++ (toString meters_tens)
            ++ (toString meters_ones)
            ++ " km"


view : Model -> Html Msg
view model =
    div [ class "cpanel" ]
        [ div [ class "cpanel-readout" ]
              [ div [ class "cpanel-readout-speed" ]
                    [ text ((toString ((toFloat model.speed) * speed_increment)) ++ " km/h" ) ] 
              , div [ class "cpanel-readout-time" ]
                  [ text (formatTime (model.currentTime - model.startTime)) ]
              , div [ class "cpanel-readout-distance" ]
                  [ text (formatDistance model.distance) ] ]
        , div [ class "cpanel-buttons" ]
            [ button
                  [ class "cpanel-button"
                  , onClick IncreaseSpeed ]
                  [ text "+" ]
            , button
                  [ class "cpanel-button"
                  , onClick DecreaseSpeed ]
                  [ text "-" ]
            ]
        , div [] [ button
                       [ class "cpanel-preset-button"
                       , onClick (SetSpeed 10)]
                       [ text "2"]
                 , button
                       [ class "cpanel-preset-button"
                       , onClick (SetSpeed 20)]
                       [ text "4"]
                 , button
                       [ class "cpanel-preset-button"
                       , onClick (SetSpeed 30)]
                       [ text "6"]
                 , button
                       [ class "cpanel-preset-button"
                       , onClick (SetSpeed 40)]
                       [ text "8"]
                 , button
                       [ class "cpanel-preset-button"
                       , onClick (SetSpeed 50)]
                       [ text "10"]
                 , button
                       [ class "cpanel-preset-button"
                       , onClick (SetSpeed 60)]
                       [ text "12"]
                 ]
        , div [] [ button
                       [ class "cpanel-start-button"
                       , onClick (SetSpeed 10) ]
                       [ text "Start" ]
                 , button
                       [ class "cpanel-stop-button"
                       , onClick (SetSpeed 0) ]
                       [ text "Stop" ]
                 ]
        , div [] [ text model.error ]
        ]
        
