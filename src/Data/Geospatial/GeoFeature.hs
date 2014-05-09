{-# LANGUAGE NoImplicitPrelude, OverloadedStrings, TemplateHaskell #-}
-------------------------------------------------------------------
-- |
-- Module       : Data.Geospatial.GeoFeature
-- Copyright    : (C) 2014 Dom De Re
-- License      : BSD-style (see the file etc/LICENSE.md)
-- Maintainer   : Dom De Re
--
-- See Section 2.2 /Feature Objects/ of the GeoJSON spec.
-- Parameterised on the property type
--
-------------------------------------------------------------------
module Data.Geospatial.GeoFeature (
    -- * Types
        GeoFeature(..)
    -- * Lenses
    ,   bbox
    ,   geometry
    ,   properties
    ,   featureId
    ) where

import Data.Geospatial.BasicTypes
import Data.Geospatial.Geometry
import Data.Geospatial.Geometry.Aeson
import Data.Geospatial.GeoPosition

import Prelude ( Show, Eq(..), ($) )
import Control.Applicative ( (<$>), (<*>) )
import Control.Lens ( makeLenses )
import Control.Monad ( mzero )
import Data.Aeson ( FromJSON(..), ToJSON(..), Value(..), Object, (.:), (.:?), (.=), object )
import Data.List ( (++) )
import Data.Maybe ( Maybe )
import Data.Text ( Text )

-- $setup
--
-- >>> import Data.LinearRing
--
-- >>> import Control.Monad ( return )
-- >>> import qualified Data.Aeson as A
-- >>> import qualified Data.ByteString.Lazy.Char8 as BS
-- >>> import Data.Function ( (.) )
-- >>> import Data.Int ( Int )
-- >>> import Data.Maybe ( Maybe(..) )
-- >>> import Data.String
-- >>> import qualified Data.Text as T
--
-- >>> let decode' = A.decode . BS.pack; decode' :: (FromJSON a) => String -> Maybe a
--
-- Test Bounding Box Data
-- >>> let lshapedPolyVertices = return (makeLinearRing [[120.0, -15.0], [127.0, -15.0], [127.0, -25.0]] [124.0, -25.0] [124.0, -18.0] [120.0, -18.0]) :: [LinearRing GeoPositionWithoutCRS]
-- >>> let lshapedPolyLineVertices = [[120.0, -15.0], [127.0, -15.0], [127.0, -25.0], [124.0, -25.0], [124.0, -18.0], [120.0, -18.0]] :: [GeoPositionWithoutCRS]
-- >>> let emptyVertices = [] :: [LinearRing GeoPositionWithoutCRS]
-- >>> let emptyLineVertices = [] :: [GeoPositionWithoutCRS]
-- >>> let testLatLonBBox = [-32, 147.5, -29.5, 151.0] :: BoundingBoxWithoutCRS
-- >>> let testLatLonBBoxJSON = "[-32,147.5,-29.5,151]"
-- >>> let testEmptyBBox = [] :: BoundingBoxWithoutCRS
-- >>> let testEmptyBBoxJSON = "[]"
--
-- End Test Bounding Box Data
-- Test Geometry Data
-- Polys
-- >>> let lShapedPolyJSON = "{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}"
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
-- >>> let lShapedGeoLine = GeoLine lshapedPolyLineVertices
-- >>> let lShapedLine = Line lShapedGeoLine
-- >>> let emptyLineJSON = "{\"type\":\"Line\",\"coordinates\":[]}"
-- >>> let emptyGeoLine = GeoLine emptyLineVertices
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
-- Test Properties
-- >>> let testProperties = object [(T.pack "depth") .= (5 :: Int), (T.pack "comment") .= (T.pack "Bore run over by dump truck")]
--
-- Test Features
-- >>> let bigFeatureJSON = "{\"bbox\":[-32,147.5,-29.5,151],\"geometry\":{\"geometries\":[{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"GeometryCollection\"},\"id\":\"GW001\",\"type\":\"Feature\",\"properties\":{\"depth\":5,\"comment\":\"Bore run over by dump truck\"}}"
-- >>> let bigFeature = GeoFeature (Just testLatLonBBox) bigassCollection testProperties (Just "GW001")
-- >>> let featureWithNoPropertiesJSON = "{\"bbox\":[-32,147.5,-29.5,151],\"geometry\":{\"geometries\":[{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"GeometryCollection\"},\"id\":\"GW001\",\"type\":\"Feature\",\"properties\":null}"
-- >>> let featureWithNoProperties = let GeoFeature bbox geometry _ featureId = bigFeature in GeoFeature bbox geometry Null featureId
-- >>> let featureWithNoGeometryJSON = "{\"type\":\"Feature\",\"properties\":{\"depth\":5,\"comment\":\"Bore run over by dump truck\"},\"geometry\":null,\"bbox\":[-32,147.5,-29.5,151],\"id\":\"GW001\"}"
-- >>> let featureWithNoGeometry = let GeoFeature bbox _ props featureId = bigFeature in GeoFeature bbox NoGeometry props featureId
-- >>> let featureWithNoIdJSON = "{\"bbox\":[-32,147.5,-29.5,151],\"geometry\":{\"geometries\":[{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"GeometryCollection\"},\"type\":\"Feature\",\"properties\":{\"depth\":5,\"comment\":\"Bore run over by dump truck\"}}"
-- >>> let featureWithNoId = let GeoFeature bbox geometry props _ = bigFeature in GeoFeature bbox geometry props Nothing
-- >>> let featureWithNoBBoxJSON = "{\"geometry\":{\"geometries\":[{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"MultiLine\"},{\"coordinates\":[],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[],\"type\":\"Line\"}],\"type\":\"MultiLine\"},{\"coordinates\":[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18]],\"type\":\"Line\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"},{\"coordinates\":[],\"type\":\"MultiPolygon\"},{\"coordinates\":[[[120,-15],[127,-15],[127,-25],[124,-25],[124,-18],[120,-18],[120,-15]]],\"type\":\"Polygon\"}],\"type\":\"GeometryCollection\"},\"id\":\"GW001\",\"type\":\"Feature\",\"properties\":{\"depth\":5,\"comment\":\"Bore run over by dump truck\"}}"
-- >>> let featureWithNoBBox = let GeoFeature _ geometry props featureId = bigFeature in GeoFeature Nothing geometry props featureId
--

-- | See Section 2.2 /Feature Objects/ of the GeoJSON spec.
-- Parameterised on the property type
data GeoFeature a = GeoFeature {
    _bbox :: Maybe BoundingBoxWithoutCRS,
    _geometry :: GeospatialGeometry,
    _properties :: a,
    _featureId :: Maybe FeatureID } deriving (Show, Eq)

makeLenses ''GeoFeature

-- instances

-- | decodes Feature objects to and from GeoJSON
--
-- >>> decode' bigFeatureJSON == Just bigFeature
-- True
--
-- >>> decode' featureWithNoPropertiesJSON == Just featureWithNoProperties
-- True
--
-- >>> decode' featureWithNoIdJSON == Just featureWithNoId
-- True
--
-- >>> decode' featureWithNoBBoxJSON == Just featureWithNoBBox
-- True
--
-- >>> decode' featureWithNoGeometryJSON == Just featureWithNoGeometry
-- True
--
instance (FromJSON a) => FromJSON (GeoFeature a) where
--  parseJSON :: Value -> Parse a
    parseJSON (Object obj) = do
        objType <- obj .: ("type" :: Text)
        if objType /= ("Feature" :: Text)
            then
                mzero
            else
                GeoFeature
                    <$> obj .:? ("bbox" :: Text)
                    <*> obj .: ("geometry" :: Text)
                    <*> obj .: ("properties" :: Text)
                    <*> obj .:? ("id" :: Text)
    parseJSON _ = mzero

-- | encodes Feature objects to and from GeoJSON
--
-- >>> (A.decode . A.encode) bigFeature == Just bigFeature
-- True
--
-- >>> (A.decode . A.encode) featureWithNoProperties == Just featureWithNoProperties
-- True
--
-- >>> (A.decode . A.encode) featureWithNoId == Just featureWithNoId
-- True
--
-- >>> (A.decode . A.encode) featureWithNoBBox == Just featureWithNoBBox
-- True
--
-- >>> (A.decode . A.encode) featureWithNoGeometry == Just featureWithNoGeometry
-- True
--
instance (ToJSON a) => ToJSON (GeoFeature a) where
--  toJSON :: a -> Value
    toJSON (GeoFeature bbox' geom props featureId') = object $ baseAttributes ++ optAttributes "bbox" bbox' ++ optAttributes "id" featureId'
        where
            baseAttributes = ["type" .= ("Feature" :: Text), "properties" .= props, "geometry" .= geom]
