port module Main exposing (main)

import Browser
import Html exposing (Html, button, div, h1, text, span)
import Html.Attributes exposing (class, id)
import Html.Events exposing (onClick)
import Json.Decode as Decode

port sendLoadFiles : String -> Cmd msg

port onFilesLoaded : (String -> msg) -> Sub msg

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

type alias Model =
    { files : List FileEntry
    , currentPath : String
    , errorMsg : Maybe String
    }

type alias FileEntry =
    { name : String
    , kind : String
    }

init : () -> ( Model, Cmd Msg )
init _ =
    ( { files = []
      , currentPath = "."
      , errorMsg = Nothing
      }
    , Cmd.none
    )

type Msg
    = FilesLoaded String
    | NavigateUp
    | NavigateToDir String
    | NoOp

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FilesLoaded json ->
            case Decode.decodeString (Decode.list fileEntryDecoder) json of
                Ok files ->
                    let
                        sortedFiles = List.sortBy .kind files -- simple sort, maybe sort by name too
                    in
                    ( { model | files = sortedFiles, errorMsg = Nothing }
                    , Cmd.none
                    )
                Err error ->
                    ( { model | errorMsg = Just ("Failed to parse file list: " ++ Decode.errorToString error) }
                    , Cmd.none
                    )

        NavigateUp ->
            if model.currentPath == "." then
                ( model, Cmd.none )
            else
                let
                    parentPath = getParentPath model.currentPath
                in
                ( { model | currentPath = parentPath }
                , sendLoadFiles parentPath
                )

        NavigateToDir dirName ->
            let
                newPath = joinPath model.currentPath dirName
            in
            ( { model | currentPath = newPath }
            , sendLoadFiles newPath
            )

        NoOp ->
            ( model, Cmd.none )

fileEntryDecoder : Decode.Decoder FileEntry
fileEntryDecoder =
    Decode.map2 FileEntry
        (Decode.field "name" Decode.string)
        (Decode.field "kind" Decode.string)

view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ div [ class "header" ]
            [ button [ id "up-btn", onClick NavigateUp ] [ text "↑ Up" ]
            , h1 [ id "current-path" ] [ text model.currentPath ]
            ]
        , div [ id "file-list" ] (List.map viewFile model.files)
        , case model.errorMsg of
            Just error ->
                div [ class "error" ] [ text error ]
            Nothing ->
                text ""
        ]

viewFile : FileEntry -> Html Msg
viewFile entry =
    let
        isDir = entry.kind == "directory"
        icon = if isDir then "📁" else "📄"
        clickAttr = if isDir then [ onClick (NavigateToDir entry.name) ] else []
        classes = "file-item" ++ (if isDir then " is-directory" else "")
        iconClass = "file-icon" ++ (if isDir then " dir-icon" else " doc-icon")
    in
    div ([ class classes ] ++ clickAttr)
        [ span [ class iconClass ] [ text icon ]
        , span [ class "file-name" ] [ text entry.name ]
        ]

subscriptions : Model -> Sub Msg
subscriptions model =
    onFilesLoaded FilesLoaded

-- HELPERS

getParentPath : String -> String
getParentPath path =
    if path == "." then
        "."
    else
        let
            parts = String.split "/" path
            parentParts = List.take ((List.length parts) - 1) parts
        in
            if List.isEmpty parentParts then
                "."
            else
                String.join "/" parentParts

joinPath : String -> String -> String
joinPath dir name =
    if dir == "." then
        name
    else if String.endsWith "/" dir then
        dir ++ name
    else
        dir ++ "/" ++ name
