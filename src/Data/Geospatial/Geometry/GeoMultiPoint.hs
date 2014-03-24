{-# LANGUAGE TemplateHaskell #-}
-------------------------------------------------------------------
-- |
-- Module       : Data.Geospatial.Geometry.GeoMultiPoint
-- Copyright    : (C) 2014 Dom De Re
-- License      : BSD-style (see the file etc/LICENSE.md)
-- Maintainer   : Dom De Re
--
-------------------------------------------------------------------
module Data.Geospatial.Geometry.GeoMultiPoint (
    -- * Type
        GeoMultiPoint(..)
    -- * Lenses
    ,   unGeoMultiPoint
    ) where

import Data.Geospatial.BasicTypes
import Data.Geospatial.Geometry.GeoPoint
import Data.Geospatial.Geometry.Aeson
import Data.Geospatial.Geometry.JSON

import Control.Lens ( makeLenses )
import Control.Monad ( mzero )
import Data.Aeson ( FromJSON(..), ToJSON(..), Value(..), Object )
import Text.JSON ( JSON(..) )

newtype GeoMultiPoint = GeoMultiPoint { _unGeoMultiPoint :: [GeoPoint] } deriving (Show, Eq)

makeLenses ''GeoMultiPoint

-- instances

instance JSON GeoMultiPoint where
    readJSON = readGeometryGeoJSON "MultiPoint" GeoMultiPoint

    showJSON (GeoMultiPoint points) = makeGeometryGeoJSON "MultiPoint" points

instance ToJSON GeoMultiPoint where
--  toJSON :: a -> Value
    toJSON = makeGeometryGeoAeson "MultiPoint" . _unGeoMultiPoint

instance FromJSON GeoMultiPoint where
--  parseJSON :: Value -> Parser a
    parseJSON (Object o)    = readGeometryGeoAeson "MultiPoint" GeoMultiPoint o
    parseJSON _             = mzero
