module Date.Format
  ( format
  , formatUtc
  , formatOffset
  , isoString
  , utcIsoString
  , isoDateString
  , utcIsoDateString
  , isoFormat
  , isoMsecFormat
  , isoOffsetFormat
  , isoMsecOffsetFormat
  , isoDateFormat
  , isoTimeFormat
  ) where

{-| Date Format, turning dates into strings.

The format code originally came from and was modified and extended from.
https://github.com/mgold/elm-date-format/blob/1.0.4/src/Date/Format.elm

## Notes
* formatUtc and formatOffset are very new and not well tested.
* hackDateAsUtc and hackDateAsOffset not sure should be exposed.

## Date presentation
@docs format
@docs formatUtc
@docs formatOffset

## Extra presentation convenience
@docs isoString
@docs utcIsoString

## Low level formats used in specific places in library.
@docs isoDateString
@docs utcIsoDateString

## Useful strings for format
@docs isoFormat
@docs isoMsecFormat
@docs isoOffsetFormat
@docs isoMsecOffsetFormat
@docs isoDateFormat
@docs isoTimeFormat

Copyright (c) 2016 Robin Luiten
-}

import Date exposing (Date, Month)
import Regex
import String exposing (padLeft)

import Date.Config as Config
import Date.Core as Core
import Date.Create as Create
import Date.Config.Config_en_us as English


{-| ISO date time, 24hr. -}
isoFormat : String
isoFormat = "%Y-%m-%dT%H:%M:%S"


{-| ISO Date time with milliseconds, 24hr. -}
isoMsecFormat : String
isoMsecFormat = "%Y-%m-%dT%H:%M:%S.%L"


{-| ISO Date time with timezone, 24hr. -}
isoOffsetFormat : String
isoOffsetFormat = "%Y-%m-%dT%H:%M:%S%z"


{-| ISO Date time with milliseconds and timezone, 24hr. -}
isoMsecOffsetFormat : String
isoMsecOffsetFormat = "%Y-%m-%dT%H:%M:%S.%L%z"


{-| ISO Date. -}
isoDateFormat : String
isoDateFormat = "%Y-%m-%d"


{-| ISO Time 24hr. -}
isoTimeFormat : String
isoTimeFormat = "%H:%M:%S"


month : Date -> String
month date =
  padLeft 2 '0' <| toString (Core.monthToInt (Date.month date))


monthMonth : Month -> String
monthMonth month =
  padLeft 2 '0' <| toString (Core.monthToInt month)


year : Date -> String
year date =
  padLeft 4 '0' <| toString (Date.year date)


yearInt : Int -> String
yearInt year =
  padLeft 4 '0' <| toString year


{-| Return date and time as string in local zone. -}
isoString : Date -> String
isoString =
  format English.config isoMsecOffsetFormat


{-| Return date and time as string in ISO form with Z for UTC offset. -}
utcIsoString : Date -> String
utcIsoString date =
    (formatUtc English.config isoMsecFormat date) ++ "Z"


{-| Utc variant of isoDateString.

Low level routine required by areas like checkDateResult to avoid
recursive loops in Format.format.
-}
utcIsoDateString : Date -> String
utcIsoDateString date =
  (isoDateString (hackDateAsUtc date))


{-| Return date as string.

Low level routine required by areas like checkDateResult to avoid
recursive loops in Format.format.
-}
isoDateString : Date -> String
isoDateString date =
  let
    year = Date.year date
    month = Date.month date
    day = Date.day date
  in
    (String.padLeft 4 '0' (toString year)) ++ "-" ++
    (String.padLeft 2 '0' (toString (Core.monthToInt month))) ++ "-" ++
    (String.padLeft 2 '0' (toString day))


-- candidate deprecation, once move to format
{-| Adjust date as if it was in utc zone. -}
hackDateAsUtc : Date -> Date
hackDateAsUtc date =
  hackDateAsOffset (Create.getTimezoneOffset date) date


{-| Adjust date for time zone offset in minutes. -}
hackDateAsOffset : Int -> Date -> Date
hackDateAsOffset offsetMinutes date =
  --  Core.fromTime <| Core.toTime date + (offsetMinutes * Core.ticksAMinute)
  -- let _ = Debug.log("hackDateAsOffset") (offsetMinutes)
  -- in
  Core.toTime date
  |> (+) (offsetMinutes * Core.ticksAMinute)
  |> Core.fromTime


{- Date formatter.

Initially from https://github.com/mgold/elm-date-format/blob/1.0.4/src/Date/Format.elm.
-}
formatRegex : Regex.Regex
formatRegex = Regex.regex "%(Y|m|B|b|d|e|A|a|H|k|I|l|p|P|M|S|%|L|z|:z)"


{-| Use a format string to format a date.
This gets time zone offset from provided date.
-}
format : Config.Config -> String -> Date.Date -> String
format config formatStr date =
  formatOffset config (Create.getTimezoneOffset date) formatStr date


{-| Convert date to utc then format it with offset set to 0 if rendered. -}
formatUtc : Config.Config -> String -> Date.Date -> String
formatUtc config formatStr date =
  -- let _ = Debug.log ("formatUtc utcIsoString") (utcIsoString date, Core.ticksAMinute)
  -- in
  formatOffset config 0 formatStr date


{-| This adjusts date for offset, and renders with the offset -}
formatOffset : Config.Config -> Int -> String -> Date.Date -> String
formatOffset config offset formatStr date =
  let
    hackOffset = (Create.getTimezoneOffset date) - offset
  in
  (Regex.replace Regex.All formatRegex)
    ( formatToken
        config
        offset
        (hackDateAsOffset hackOffset date)
    )
    formatStr


formatToken : Config.Config -> Int -> Date.Date -> Regex.Match -> String
formatToken config offset d m =
  let
    symbol = List.head m.submatches |> collapse |> Maybe.withDefault " "
  in
    case symbol of
      "Y" -> d |> Date.year |> padWithN 4 '0'
      "m" -> d |> Date.month |> Core.monthToInt |> padWith '0'
      "B" -> d |> Date.month |> config.i18n.monthName
      "b" -> d |> Date.month |> config.i18n.monthShort
      "d" -> d |> Date.day |> padWith '0'
      "e" -> d |> Date.day |> padWith ' '
      "A" -> d |> Date.dayOfWeek |> config.i18n.dayName
      "a" -> d |> Date.dayOfWeek |> config.i18n.dayShort
      "H" -> d |> Date.hour |> padWith '0'
      "k" -> d |> Date.hour |> padWith ' '
      "I" -> d |> Date.hour |> mod12 |> padWith '0'
      "l" -> d |> Date.hour |> mod12 |> padWith ' '
      "p" -> if Date.hour d < 13 then "AM" else "PM"
      "P" -> if Date.hour d < 13 then "am" else "pm"
      "M" -> d |> Date.minute |> padWith '0'
      "S" -> d |> Date.second |> padWith '0'
      "L" -> d |> Date.millisecond |> padWithN 3 '0'
      "%" -> symbol
      "z" -> formatOffsetStr "" offset
      ":z" -> formatOffsetStr ":" offset
      _ -> ""


collapse : Maybe (Maybe a) -> Maybe a
collapse m = Maybe.andThen m identity


formatOffsetStr : String -> Int -> String
formatOffsetStr betweenHoursMinutes offset =
  let
    (hour, minute) = toHourMin (abs offset)
  in
    ( if offset <= 0 then
        "+" -- "+" is displayed for negative offset.
      else
        "-"
    )
    ++ (padWith '0' hour)
    ++ betweenHoursMinutes
    ++ (padWith '0' minute)


mod12 h =
  if h % 12 == 0 then
    12
  else
    h % 12


padWith : Char -> a -> String
padWith c =
  padLeft 2 c << toString


padWithN : Int -> Char -> a -> String
padWithN n c =
  padLeft n c << toString


{- Return time zone offset in Hours and Minutes from minutes. -}
toHourMin : Int -> (Int, Int)
toHourMin offsetMinutes =
  (offsetMinutes // 60, offsetMinutes % 60)
