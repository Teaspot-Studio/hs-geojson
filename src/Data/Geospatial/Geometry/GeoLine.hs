{-# LANGUAGE TemplateHaskell #-}
-------------------------------------------------------------------
-- |
-- Module       : Data.Geospatial.Geometry.GeoLine
-- Copyright    : (C) 2014 Dom De Re
-- License      : BSD-style (see the file etc/LICENSE.md)
-- Maintainer   : Dom De Re
--
-------------------------------------------------------------------
module Data.Geospatial.Geometry.GeoLine (
    -- * Type
        GeoLine(..)
    -- * Lenses
    ,   unGeoLine
    ) where

import Data.Geospatial.BasicTypes
import Data.Geospatial.Geometry.Aeson
import Data.Geospatial.Geometry.JSON

import Control.Lens ( makeLenses )
import Control.Monad ( mzero )
import Data.Aeson ( FromJSON(..), ToJSON(..), Value(..), Object )
import Text.JSON ( JSON(..) )

newtype GeoLine = GeoLine { _unGeoLine :: [GeoPositionWithoutCRS] } deriving (Show, Eq)

makeLenses ''GeoLine

-- instances

instance JSON GeoLine where
    readJSON = readGeometryGeoJSON "Line" GeoLine

    showJSON (GeoLine line) = makeGeometryGeoJSON "Line" line

instance ToJSON GeoLine where
--  toJSON :: a -> Value
    toJSON = makeGeometryGeoAeson "Line" . _unGeoLine

instance FromJSON GeoLine where
--  parseJSON :: Value -> Parser a
    parseJSON (Object o)    = readGeometryGeoAeson "Line" GeoLine o
    parseJSON _             = mzero
