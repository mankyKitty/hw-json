{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module HaskellWorks.Data.Json.LightJson where

import Control.Arrow
import Data.String
import HaskellWorks.Data.Json.Internal.Doc
import HaskellWorks.Data.MQuery
import HaskellWorks.Data.MQuery.AtLeastSize
import HaskellWorks.Data.MQuery.Entry
import HaskellWorks.Data.MQuery.Micro
import HaskellWorks.Data.MQuery.Mini
import HaskellWorks.Data.MQuery.Row
import Prelude                              hiding (drop)
import Text.PrettyPrint.ANSI.Leijen

import qualified Data.ByteString as BS

data LightJson c
  = LightJsonString String
  | LightJsonNumber BS.ByteString
  | LightJsonObject [(String, c)]
  | LightJsonArray [c]
  | LightJsonBool Bool
  | LightJsonNull
  | LightJsonError String
  deriving Show

instance Eq (LightJson c) where
  (==) (LightJsonString a) (LightJsonString b) = a == b
  (==) (LightJsonNumber a) (LightJsonNumber b) = a == b
  (==) (LightJsonBool   a) (LightJsonBool   b) = a == b
  (==)  LightJsonNull       LightJsonNull      = True
  (==)  _                   _                  = False

data LightJsonField c = LightJsonField String (LightJson c)

class LightJsonAt a where
  lightJsonAt :: a -> LightJson a

instance LightJsonAt c => Pretty (LightJsonField c) where
  pretty (LightJsonField k v) = text (show k) <> text ": " <> pretty v

instance LightJsonAt c => Pretty (LightJson c) where
  pretty c = case c of
    LightJsonString s   -> dullgreen  (text (show s))
    LightJsonNumber n   -> cyan       (text (show n))
    LightJsonObject []  -> text "{}"
    LightJsonObject kvs -> hEncloseSep (text "{") (text "}") (text ",") ((pretty . toLightJsonField . second lightJsonAt) `map` kvs)
    LightJsonArray vs   -> hEncloseSep (text "[") (text "]") (text ",") ((pretty . lightJsonAt) `map` vs)
    LightJsonBool w     -> red (text (show w))
    LightJsonNull       -> text "null"
    LightJsonError s    -> text "<error " <> text s <> text ">"
    where toLightJsonField :: (String, LightJson c) -> LightJsonField c
          toLightJsonField (k, v) = LightJsonField k v

instance Pretty (Micro (LightJson c)) where
  pretty (Micro (LightJsonString s )) = dullgreen (text (show s))
  pretty (Micro (LightJsonNumber n )) = cyan      (text (show n))
  pretty (Micro (LightJsonObject [])) = text "{}"
  pretty (Micro (LightJsonObject _ )) = text "{..}"
  pretty (Micro (LightJsonArray [] )) = text "[]"
  pretty (Micro (LightJsonArray _  )) = text "[..]"
  pretty (Micro (LightJsonBool w   )) = red (text (show w))
  pretty (Micro  LightJsonNull      ) = text "null"
  pretty (Micro (LightJsonError s  )) = text "<error " <> text s <> text ">"

instance Pretty (Micro (String, LightJson c)) where
  pretty (Micro (fieldName, jpv)) = red (text (show fieldName)) <> text ": " <> pretty (Micro jpv)

instance LightJsonAt c => Pretty (Mini (LightJson c)) where
  pretty mjpv = case mjpv of
    Mini (LightJsonString s   ) -> dullgreen  (text (show s))
    Mini (LightJsonNumber n   ) -> cyan       (text (show n))
    Mini (LightJsonObject []  ) -> text "{}"
    Mini (LightJsonObject kvs ) -> case kvs of
      (_:_:_:_:_:_:_:_:_:_:_:_:_) -> text "{" <> prettyKvs (map (second lightJsonAt) kvs) <> text ", ..}"
      []                          -> text "{}"
      _                           -> text "{" <> prettyKvs (map (second lightJsonAt) kvs) <> text "}"
    Mini (LightJsonArray []   ) -> text "[]"
    Mini (LightJsonArray vs   ) | vs `atLeastSize` 11 -> text "[" <> nest 2 (prettyVs ((Micro . lightJsonAt) `map` take 10 vs)) <> text ", ..]"
    Mini (LightJsonArray vs   ) | vs `atLeastSize` 1  -> text "[" <> nest 2 (prettyVs ((Micro . lightJsonAt) `map` take 10 vs)) <> text "]"
    Mini (LightJsonArray _    )                       -> text "[]"
    Mini (LightJsonBool w     ) -> red (text (show w))
    Mini  LightJsonNull         -> text "null"
    Mini (LightJsonError s    ) -> text "<error " <> text s <> text ">"

instance LightJsonAt c => Pretty (Mini (String, LightJson c)) where
  pretty (Mini (fieldName, jpv)) = text (show fieldName) <> text ": " <> pretty (Mini jpv)

instance LightJsonAt c => Pretty (MQuery (LightJson c)) where
  pretty = pretty . Row 120 . mQuery

instance LightJsonAt c => Pretty (MQuery (Entry String (LightJson c))) where
  pretty (MQuery das) = pretty (Row 120 das)
