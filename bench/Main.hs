{-# LANGUAGE BangPatterns        #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Control.Monad
import Criterion.Main
import Data.List
import Data.Word
import Foreign
import HaskellWorks.Data.Json.Internal.Backend.Standard.Blank
import HaskellWorks.Data.Json.Internal.Backend.Standard.MakeIndex
import System.IO.MMap

import qualified Data.ByteString                              as BS
import qualified Data.ByteString.Internal                     as BSI
import qualified HaskellWorks.Data.Json.Backend.Standard.Fast as FAST
import qualified HaskellWorks.Data.Json.Backend.Standard.Slow as SLOW
import qualified System.Directory                             as IO

setupEnvJson :: FilePath -> IO BS.ByteString
setupEnvJson filepath = do
  (fptr :: ForeignPtr Word8, offset, size) <- mmapFileForeignPtr filepath ReadOnly Nothing
  let !bs = BSI.fromForeignPtr (castForeignPtr fptr) offset size
  return bs

jsonToInterestBits3 :: [BS.ByteString] -> [BS.ByteString]
jsonToInterestBits3 = blankedJsonToInterestBits . blankJson

makeBenchBlankJson :: IO [Benchmark]
makeBenchBlankJson = do
  entries <- IO.listDirectory "corpus/bench"
  let files = ("corpus/bench/" ++) <$> (".json" `isSuffixOf`) `filter` entries
  benchmarks <- forM files $ \file -> return
    [ env (setupEnvJson file) $ \bs -> bgroup file
      [ bench "Run blankJson" (whnf (BS.concat . blankJson) [bs])
      ]
    ]

  return (join benchmarks)

makeBenchJsonToInterestBits :: IO [Benchmark]
makeBenchJsonToInterestBits = do
  entries <- IO.listDirectory "corpus/bench"
  let files = ("corpus/bench/" ++) <$> (".json" `isSuffixOf`) `filter` entries
  benchmarks <- forM files $ \file -> return
    [ env (setupEnvJson file) $ \bs -> bgroup file
      [ bench "Run blankJson" (whnf (BS.concat . jsonToInterestBits3) [bs])
      ]
    ]

  return (join benchmarks)

makeBenchMakeCursor :: IO [Benchmark]
makeBenchMakeCursor = do
  entries <- IO.listDirectory "corpus/bench"
  let files = ("corpus/bench/" ++) <$> (".json" `isSuffixOf`) `filter` entries
  benchmarks <- forM files $ \file -> return
    [ env (setupEnvJson file) $ \bs -> bgroup file
      [ bench "Run slow make cursor" (whnf SLOW.makeCursor bs)
      , bench "Run fast make cursor" (whnf FAST.makeCursor bs)
      ]
    ]

  return (join benchmarks)

main :: IO ()
main = do
  benchmarks <- mconcat <$> sequence
    [ makeBenchBlankJson
    , makeBenchJsonToInterestBits
    , makeBenchMakeCursor
    ]
  defaultMain benchmarks
