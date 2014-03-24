{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
-------------------------------------------------------------------
-- |
-- Module       : Data.Geospatial.Geometry
-- Copyright    : (C) 2014 Dom De Re
-- License      : BSD-style (see the file etc/LICENSE.md)
-- Maintainer   : Dom De Re
--
-- See section 2.1 "Geometry Objects" in the GeoJSON Spec.
--
-------------------------------------------------------------------
module Data.Geospatial.Geometry (
    -- * Types
        GeoPoint(..)
    ,   GeoMultiPoint(..)
    ,   GeoPolygon(..)
    ,   GeoMultiPolygon(..)
    ,   GeoLine(..)
    ,   GeoMultiLine(..)
    ,   GeospatialGeometry(..)
    -- * Lenses
    ,   unGeoPoint
    ,   unGeoMultiPoint
    ,   unGeoPolygon
    ,   unGeoMultiPolygon
    ,   unGeoLine
    ,   unGeoMultiLine
    -- * Prisms
    ,   _NoGeometry
    ,   _Point
    ,   _MultiPoint
    ,   _Polygon
    ,   _MultiPolygon
    ,   _Line
    ,   _MultiLine
    ,   _Collection
    ) where

import Data.Geospatial.Geometry.Aeson
import Data.Geospatial.Geometry.GeoLine
import Data.Geospatial.Geometry.GeoMultiLine
import Data.Geospatial.Geometry.GeoMultiPoint
import Data.Geospatial.Geometry.GeoMultiPolygon
import Data.Geospatial.Geometry.GeoPoint
import Data.Geospatial.Geometry.GeoPolygon
import Data.Geospatial.Geometry.JSON

import Control.Applicative ( (<$>) )
import Control.Lens ( makePrisms )
import Control.Monad ( mzero )
import Data.Aeson
    (   FromJSON(..)
    ,   ToJSON(..)
    ,   Value(..)
    ,   Object
    ,   (.=)
    ,   object
    )
import Data.Text ( Text )
import Text.JSON ( JSON(..), JSValue(..), Result(..), makeObj, valFromObj, readJSON )

-- $setup
-- >>> import Data.Geospatial.BasicTypes
--
-- >>> import qualified Data.Aeson as A
-- >>> import qualified Text.JSON as J
--
-- >>> let lshapedPolyVertices = [[120.0, -15.0], [127.0, -15.0], [127.0, -25.0], [124.0, -25.0], [124.0, -18.0], [120.0, -18.0]] :: [GeoPositionWithoutCRS]
-- >>> let emptyVertices = [] :: [GeoPositionWithoutCRS]
--
-- Test Geometry Data
-- Polys
-- >>> let lShapedPolyJSON = "{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}"
--
-- Upside down L Shaped Poly
--
-- (120, -15)                (127, -15)
-- *---------------------------*
-- |                           |
-- |                           |
-- |             (124, -18)    |
-- *---------------*           |
-- (120, -18)      |           |
--                 |           |
--                 |           |
--                 |           |
--                 |           |
--                 |           |
--                 |           |
--                 *-----------*
--               (124, -25)  (127, -25)
--
-- >>> let lShapedGeoPoly = GeoPolygon lshapedPolyVertices
-- >>> let lShapedPoly = Polygon lShapedGeoPoly
-- >>> let emptyPolyJSON = "{\"type\":\"Polygon\",\"coordinates\":[]}"
-- >>> let emptyGeoPoly = GeoPolygon emptyVertices
-- >>> let emptyPoly = Polygon emptyGeoPoly
--
-- Multi Polys
-- >>> let emptyMultiPolyJSON = "{\"type\":\"MultiPolygon\",\"coordinates\":[]}"
-- >>> let emptyMultiGeoPoly = GeoMultiPolygon []
-- >>> let emptyMultiPoly = MultiPolygon emptyMultiGeoPoly
-- >>> let singlePolyMultiPolyJSON = "{\"type\":\"MultiPolygon\",\"coordinates\":[{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}]}"
-- >>> let singlePolyGeoMultiPoly = GeoMultiPolygon [lShapedGeoPoly]
-- >>> let singlePolyMultiPoly = MultiPolygon singlePolyGeoMultiPoly
-- >>> let multiPolyJSON = "{\"type\":\"MultiPolygon\",\"coordinates\":[{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]},{\"type\":\"Polygon\",\"coordinates\":[]}]}"
-- >>> let geoMultiPoly = GeoMultiPolygon [lShapedGeoPoly, emptyGeoPoly]
-- >>> let multiPoly = MultiPolygon geoMultiPoly
--
-- Line Data
-- >>> let lShapedLineJSON = "{\"type\":\"Line\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}"
-- >>> let lShapedGeoLine = GeoLine lshapedPolyVertices
-- >>> let lShapedLine = Line lShapedGeoLine
-- >>> let emptyLineJSON = "{\"type\":\"Line\",\"coordinates\":[]}"
-- >>> let emptyGeoLine = GeoLine emptyVertices
-- >>> let emptyLine = Line emptyGeoLine
--
-- Multi Lines
-- >>> let emptyMultiLineJSON = "{\"type\":\"MultiLine\",\"coordinates\":[]}"
-- >>> let emptyMultiGeoLine = GeoMultiLine []
-- >>> let emptyMultiLine = MultiLine emptyMultiGeoLine
-- >>> let singleLineMultiLineJSON = "{\"type\":\"MultiLine\",\"coordinates\":[{\"type\":\"Line\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}]}"
-- >>> let singleLineGeoMultiLine = GeoMultiLine [lShapedGeoLine]
-- >>> let singleLineMultiLine = MultiLine singleLineGeoMultiLine
-- >>> let multiLineJSON = "{\"type\":\"MultiLine\",\"coordinates\":[{\"type\":\"Line\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]},{\"type\":\"Line\",\"coordinates\":[]}]}"
-- >>> let geoMultiLine = GeoMultiLine [lShapedGeoLine, emptyGeoLine]
-- >>> let multiLine = MultiLine geoMultiLine
-- >>> let emptyCollectionJSON = "{\"type\":\"GeometryCollection\",\"geometries\":[]}"
-- >>> let emptyCollection = Collection []
-- >>> let bigassCollectionJSON = "{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"MultiLine\",\"coordinates\":[{\"type\":\"Line\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}]},{\"type\":\"MultiLine\",\"coordinates\":[]},{\"type\":\"Line\",\"coordinates\":[]},{\"type\":\"MultiLine\",\"coordinates\":[{\"type\":\"Line\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]},{\"type\":\"Line\",\"coordinates\":[]}]},{\"type\":\"Line\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]},{\"type\":\"MultiPolygon\",\"coordinates\":[{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]},{\"type\":\"Polygon\",\"coordinates\":[]}]},{\"type\":\"MultiPolygon\",\"coordinates\":[{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}]},{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]},{\"type\":\"MultiPolygon\",\"coordinates\":[]},{\"type\":\"Polygon\",\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]]}]}"
-- >>> let bigassCollection = Collection [singleLineMultiLine, emptyMultiLine, emptyLine, multiLine, lShapedLine, multiPoly, singlePolyMultiPoly, lShapedPoly, emptyMultiPoly, lShapedPoly]
--
-- End Test Geometry Data
--
--

-- | See section 2.1 /Geometry Objects/ in the GeoJSON Spec.
data GeospatialGeometry =
        NoGeometry
    |   Point GeoPoint
    |   MultiPoint GeoMultiPoint
    |   Polygon GeoPolygon
    |   MultiPolygon GeoMultiPolygon
    |   Line GeoLine
    |   MultiLine GeoMultiLine
    |   Collection [GeospatialGeometry] deriving (Show, Eq)

makePrisms ''GeospatialGeometry

geometryFromJSON :: String -> JSValue -> Result GeospatialGeometry
geometryFromJSON "Point" obj                                = Point <$> readJSON obj
geometryFromJSON "MultiPoint" obj                           = MultiPoint <$> readJSON obj
geometryFromJSON "Polygon" obj                              = Polygon <$> readJSON obj
geometryFromJSON "MultiPolygon" obj                         = MultiPolygon <$> readJSON obj
geometryFromJSON "Line" obj                                 = Line <$> readJSON obj
geometryFromJSON "MultiLine" obj                            = MultiLine <$> readJSON obj
geometryFromJSON "GeometryCollection" (JSObject jsonObj)    = Collection <$> (valFromObj "geometries" jsonObj >>= readJSON)
geometryFromJSON "GeometryCollection" _                     = Error "Invalid value type for 'geometries' attribute.."
geometryFromJSON typeString _                               = Error $ "Invalid Geometry Type: " ++ typeString

-- |
-- encodes and decodes Geometry Objects to and from GeoJSON
-- (refer to source to see the values for the test values)
--
-- >>> J.encode NoGeometry
-- "null"
--
-- >>> J.decode "null" :: Result GeospatialGeometry
-- Ok NoGeometry
--
-- >>> J.encode lShapedPoly == lShapedPolyJSON
-- True
--
-- >>> J.decode lShapedPolyJSON == Ok lShapedPoly
-- True
--
-- >>> J.encode emptyPoly == emptyPolyJSON
-- True
--
-- >>> J.decode emptyPolyJSON == Ok emptyPoly
-- True
--
-- >>> J.encode emptyMultiPoly == emptyMultiPolyJSON
-- True
--
-- >>> J.decode emptyMultiPolyJSON == Ok emptyMultiPoly
-- True
--
-- >>> J.encode singleLineMultiLine == singleLineMultiLineJSON
-- True
--
-- >>> J.decode singleLineMultiLineJSON == Ok singleLineMultiLine
-- True
--
-- >>> J.encode multiLine == multiLineJSON
-- True
--
-- >>> J.decode multiLineJSON == Ok multiLine
-- True
--
-- >>> J.encode emptyCollection == emptyCollectionJSON
-- True
--
-- >>> J.decode emptyCollectionJSON == Ok emptyCollection
-- True
--
-- >>> J.encode bigassCollection == bigassCollectionJSON
-- True
--
-- >>> J.decode bigassCollectionJSON == Ok bigassCollection
-- True
--
instance JSON GeospatialGeometry where
    readJSON JSNull = Ok NoGeometry
    readJSON json   = do
        geometryObj <- readJSON json
        geometryType <- valFromObj "type" geometryObj
        geometryFromJSON geometryType (JSObject geometryObj)

    showJSON (NoGeometry)               = JSNull
    showJSON (Point point)              = showJSON point
    showJSON (MultiPoint points)        = showJSON points
    showJSON (Polygon vertices)         = showJSON vertices
    showJSON (MultiPolygon vertices)    = showJSON vertices
    showJSON (Line vertices)            = showJSON vertices
    showJSON (MultiLine vertices)       = showJSON vertices
    showJSON (Collection geometries)    = makeObj
        [   ("type", showJSON ("GeometryCollection" :: Text))
        ,   ("geometries", showJSON geometries)
        ]
-- |
-- encodes and Geometry Objects to GeoJSON
-- (refer to source to see the values for the test values)
--
-- >>> A.encode NoGeometry
-- "null"
--
-- >>> A.encode lShapedPoly == lShapedPolyJSON
-- True
--
-- >>> A.encode emptyPoly == emptyPolyJSON
-- True
--
-- >>> A.encode emptyMultiPoly == emptyMultiPolyJSON
-- True
--
-- >>> A.encode singleLineMultiLine == singleLineMultiLineJSON
-- True
--
-- >>> A.encode multiLine == multiLineJSON
-- True
--
-- >>> A.encode emptyCollection == emptyCollectionJSON
-- True
--
-- >>> A.encode bigassCollection == bigassCollectionJSON
-- True
--
instance ToJSON GeospatialGeometry where
--  toJSON :: a -> Value
    toJSON NoGeometry               = Null
    toJSON (Point point)            = toJSON point
    toJSON (MultiPoint points)      = toJSON points
    toJSON (Polygon vertices)       = toJSON vertices
    toJSON (MultiPolygon vertices)  = toJSON vertices
    toJSON (Line vertices)          = toJSON vertices
    toJSON (MultiLine vertices)     = toJSON vertices
    toJSON (Collection geometries)  = object
        [   "type" .= ("GeometryCollection" :: Text)
        ,   "geometries" .= geometries
        ]
